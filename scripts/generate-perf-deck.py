#!/usr/bin/env python3
"""
Generate `amgi-perf.anki2` — a realistically-sized collection for profiling.

Sibling of `generate-smoke-deck.py`, which covers *correctness* with 8 cards.
This one covers *performance*, where the findings only show up at scale:

  - the deck list's hero/heatmap does a 365-day revlog scan
  - the reviewer renders one card per advance
  - typed-answer reveal runs a `compareAnswer` FFI call

Against an empty collection all three measure as zero, which reads as
"no problem here" and is worse than not measuring at all.

    python3 -m venv .venv && .venv/bin/pip install genanki
    .venv/bin/python scripts/generate-perf-deck.py --out /tmp/amgi-perf.anki2

genanki builds the notes/cards/notetypes correctly (getting Anki's schema
right by hand is a bad use of anyone's time); this script then opens the
collection genanki produced and injects the two things an `.apkg` cannot
carry: a scheduling state distribution, and a review history.

Output is a bare `collection.anki2`, not an `.apkg` — importing needs UI
driving we don't have, so the file is meant to be dropped straight into a
simulator's app container. See `--help` for the install command.
"""

import argparse
import json
import os
import random
import sqlite3
import sys
import tempfile
import time
import zipfile

import genanki

# Stable so re-running overwrites rather than accumulating duplicates.
DECK_ID = 1_612_004_001
BASIC_MODEL_ID = 1_612_004_101
TYPED_MODEL_ID = 1_612_004_102
CLOZE_MODEL_ID = 1_612_004_103

DAY_MS = 86_400_000

# Card scheduling buckets. Anki: type/queue 0=new, 1=learning, 2=review.
NEW, LEARNING, REVIEW = 0, 1, 2


def make_models() -> dict:
    basic = genanki.Model(
        BASIC_MODEL_ID,
        "Perf Basic",
        fields=[{"name": "Front"}, {"name": "Back"}],
        templates=[{
            "name": "Card 1",
            "qfmt": "{{Front}}",
            "afmt": "{{FrontSide}}<hr id=answer>{{Back}}",
        }],
        css=".card { font-family: -apple-system; font-size: 30px; text-align: center; }",
    )
    # The typed-answer path is the one that used to run compareAnswer on the
    # main actor at the moment of the reveal tap.
    typed = genanki.Model(
        TYPED_MODEL_ID,
        "Perf Typed",
        fields=[{"name": "Front"}, {"name": "Answer"}],
        templates=[{
            "name": "Card 1",
            "qfmt": "{{Front}}<br>{{type:Answer}}",
            "afmt": "{{FrontSide}}<hr id=answer>{{Answer}}",
        }],
        css=".card { font-family: -apple-system; font-size: 30px; text-align: center; }",
    )
    cloze = genanki.Model(
        CLOZE_MODEL_ID,
        "Perf Cloze",
        fields=[{"name": "Text"}, {"name": "Extra"}],
        templates=[{
            "name": "Cloze",
            "qfmt": "{{cloze:Text}}",
            "afmt": "{{cloze:Text}}<br>{{Extra}}",
        }],
        model_type=genanki.Model.CLOZE,
        css=".card { font-family: -apple-system; font-size: 30px; text-align: center; }",
    )
    return {"basic": basic, "typed": typed, "cloze": cloze}


# Korean/English pairs so the rendered cards are the same shape as the real
# thing (CJK metrics, not ASCII) — text width feeds layout and WebKit cost.
STEMS = [
    ("학교", "school"), ("사람", "person"), ("시간", "time"), ("나라", "country"),
    ("음식", "food"), ("친구", "friend"), ("가족", "family"), ("날씨", "weather"),
    ("영화", "movie"), ("음악", "music"), ("책상", "desk"), ("의자", "chair"),
    ("바다", "sea"), ("하늘", "sky"), ("자동차", "car"), ("기차", "train"),
]


def make_notes(models: dict, count: int, typed_share: float, cloze_share: float) -> list:
    notes = []
    for i in range(count):
        ko, en = STEMS[i % len(STEMS)]
        ko, en = f"{ko}{i}", f"{en} {i}"
        r = (i / count)
        if r < typed_share:
            notes.append(genanki.Note(model=models["typed"], fields=[ko, en], tags=["perf", "typed"]))
        elif r < typed_share + cloze_share:
            notes.append(genanki.Note(
                model=models["cloze"],
                fields=[f"{ko} means {{{{c1::{en}}}}}", "perf"],
                tags=["perf", "cloze"],
            ))
        else:
            notes.append(genanki.Note(model=models["basic"], fields=[ko, en], tags=["perf", "basic"]))
    return notes


def build_collection(notes: list, out_path: str) -> None:
    """Write the deck via genanki, then lift the raw collection db out of it."""
    deck = genanki.Deck(DECK_ID, "Perf::Korean Vocabulary")
    for note in notes:
        deck.add_note(note)

    with tempfile.TemporaryDirectory() as tmp:
        apkg = os.path.join(tmp, "perf.apkg")
        genanki.Package(deck).write_to_file(apkg)
        with zipfile.ZipFile(apkg) as z:
            inner = next(
                (n for n in ("collection.anki21", "collection.anki2") if n in z.namelist()),
                None,
            )
            if inner is None:
                raise SystemExit(f"no collection db inside the apkg: {z.namelist()}")
            with z.open(inner) as src, open(out_path, "wb") as dst:
                dst.write(src.read())


def schedule_and_review(db_path: str, days: int, reviews_per_day: int, seed: int) -> dict:
    """Give the cards a plausible scheduling state and a `days`-long history.

    This is the half an .apkg cannot carry, and the half that makes the deck
    list's 365-day scan cost anything.
    """
    rng = random.Random(seed)
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    # Backdate the collection's creation before doing anything else.
    #
    # genanki stamps `col.crt` with the moment it ran, so a year of "past"
    # reviews predates the collection's own existence. Anki derives a review's
    # day index as (revlog.id/1000 - crt) / 86400, so every backdated row came
    # out negative and the graphs dropped them — the heatmap rendered
    # "No reviews yet" over 27k rows. Anchor crt to the 4am rollover a little
    # before the history starts.
    local_4am = time.mktime(time.localtime()[:3] + (4, 0, 0, 0, 0, -1))
    crt = int(local_4am - (days + 2) * 86_400)
    cur.execute("update col set crt = ?", (crt,))

    # Opt the collection into the v3 scheduler.
    #
    # genanki writes no `schedVer`, so the engine reads it as v1 and every
    # graphs call fails with "Your collection needs to be upgraded to the v3
    # scheduler." Deck counts still work, so the app looked fine while the
    # heatmap rendered "No reviews yet" over a full year of history — the
    # error reached `buildHeroAndHeatmap`'s `try?` and became an empty result.
    conf = json.loads(cur.execute("select conf from col").fetchone()[0])
    conf["schedVer"] = 2
    conf["sched2021"] = True
    cur.execute("update col set conf = ?", (json.dumps(conf),))

    today = int((time.time() - crt) // 86_400)                       # Anki day number
    card_ids = [r[0] for r in cur.execute("select id from cards order by id")]

    # Distribution: a mature deck in steady use, with a real backlog due today.
    # 15% never seen, 5% mid-learning, 80% in review — of which a slice is due.
    updates, states = [], {"new": 0, "learning": 0, "review": 0, "due": 0}
    for cid in card_ids:
        roll = rng.random()
        if roll < 0.15:
            updates.append((NEW, NEW, cid % 1000, 0, 0, 0, 0, cid))
            states["new"] += 1
        elif roll < 0.20:
            updates.append((LEARNING, LEARNING, int(time.time()) + rng.randint(60, 600),
                            0, 0, rng.randint(1, 3), 0, cid))
            states["learning"] += 1
        else:
            ivl = rng.choice([1, 2, 3, 5, 8, 13, 21, 34, 55, 90, 180])
            # Skew due dates so a meaningful pile has landed rather than all
            # sitting in the future — an empty due queue profiles as nothing.
            due = today - rng.randint(0, 12) if rng.random() < 0.35 else today + rng.randint(1, ivl)
            if due <= today:
                states["due"] += 1
            updates.append((REVIEW, REVIEW, due, ivl, rng.randint(1900, 2900),
                            rng.randint(1, 30), rng.randint(0, 4), cid))
            states["review"] += 1

    cur.executemany(
        "update cards set type=?, queue=?, due=?, ivl=?, factor=?, reps=?, lapses=? where id=?",
        updates,
    )

    # Review history. One row per review, ids are epoch-ms and must be unique —
    # Anki uses the revlog id as the review timestamp.
    now_ms = int(time.time() * 1000)
    rows, used = [], set()
    for day_back in range(days):
        # Vary daily volume, and leave occasional gaps so the streak and the
        # heatmap have something other than a flat wall to render.
        if rng.random() < 0.08:
            continue
        n = max(1, int(rng.gauss(reviews_per_day, reviews_per_day * 0.4)))
        base = now_ms - day_back * DAY_MS
        for _ in range(n):
            rid = base - rng.randint(0, DAY_MS - 1)
            while rid in used:
                rid += 1
            used.add(rid)
            ease = rng.choices([1, 2, 3, 4], weights=[10, 20, 55, 15])[0]
            last = rng.choice([1, 3, 8, 21, 55])
            rows.append((
                rid, rng.choice(card_ids), -1, ease,
                last * rng.choice([2, 3]), last,
                rng.randint(1900, 2900), rng.randint(1200, 25000),
                rng.choices([0, 1, 2, 3], weights=[15, 15, 65, 5])[0],
            ))

    cur.executemany(
        "insert into revlog (id, cid, usn, ease, ivl, lastIvl, factor, time, type) "
        "values (?,?,?,?,?,?,?,?,?)",
        rows,
    )
    con.commit()
    con.execute("vacuum")
    con.close()

    states["revlog"] = len(rows)
    states["cards"] = len(card_ids)
    return states


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Install into a booted simulator (app must be closed):\n"
            "  C=$(xcrun simctl get_app_container <udid> com.amgiapp.AmgiApp data)\n"
            '  D="$C/Library/Application Support/AnkiCollection/default"\n'
            '  rm -f "$D"/collection.anki2-wal "$D"/collection.anki2-shm\n'
            '  cp /tmp/amgi-perf.anki2 "$D/collection.anki2"\n'
        ),
    )
    ap.add_argument("--out", default="/tmp/amgi-perf.anki2")
    ap.add_argument("--notes", type=int, default=3000)
    ap.add_argument("--days", type=int, default=365, help="days of review history")
    ap.add_argument("--reviews-per-day", type=int, default=80)
    ap.add_argument("--typed-share", type=float, default=0.10)
    ap.add_argument("--cloze-share", type=float, default=0.10)
    ap.add_argument("--seed", type=int, default=20260821, help="fixed so runs are comparable")
    args = ap.parse_args()

    models = make_models()
    notes = make_notes(models, args.notes, args.typed_share, args.cloze_share)
    build_collection(notes, args.out)
    stats = schedule_and_review(args.out, args.days, args.reviews_per_day, args.seed)

    print(f"Wrote {args.out} ({os.path.getsize(args.out) / 1_048_576:.1f} MB)")
    print(f"  notes   {len(notes)}")
    print(f"  cards   {stats['cards']}  "
          f"(new {stats['new']}, learning {stats['learning']}, review {stats['review']})")
    print(f"  due now {stats['due']}")
    print(f"  revlog  {stats['revlog']} rows over {args.days} days")
    return 0


if __name__ == "__main__":
    sys.exit(main())
