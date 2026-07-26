#!/usr/bin/env python3
"""
Generate `amgi-smoke-test.apkg` covering the PR 1a Reviewer Rendering Core
smoke-test checklist. Run inside the repo's smoke-test venv:

    python3 -m venv /tmp/amgi-deck-venv
    /tmp/amgi-deck-venv/bin/pip install genanki
    /tmp/amgi-deck-venv/bin/python scripts/generate-smoke-deck.py

Output: /tmp/amgi-smoke-test.apkg

Cards generated (one per smoke checklist item, plus a couple of variations):

    1. Plain text (no MathJax, no audio) — baseline render
    2. MathJax inline   \\(x^2 + y^2 = z^2\\)
    3. MathJax display  \\[ \\int_0^1 x \\, dx = \\tfrac12 \\]
    4. Cloze deletion
    5. Standard with [sound:silence.mp3]
    6. Cloze with [sound:silence.mp3]
    7. Type-answer (front {{type:Answer}}, back diffed)
    8. Link card (https://example.com — verifies SFSafariViewController)

Image Occlusion is intentionally omitted — IO notes require the IO notetype
plus JSON occlusion data that genanki doesn't expose. Test IO manually with
an existing IO card or via the app's IO authoring flow.

Model IDs are stable so re-importing the deck overwrites prior copies.
"""

import os
import subprocess
import sys

import genanki

OUT_PATH = "/tmp/amgi-smoke-test.apkg"
# genanki uses the basename of the source file as the in-package media name,
# so the source filename must match the [sound:silence.mp3] reference. We
# place it in a unique subfolder to avoid colliding with other /tmp content.
SILENCE_DIR = "/tmp/amgi-smoke-fixtures"
SILENCE_PATH = f"{SILENCE_DIR}/silence.mp3"

DECK_ID = 2026050100
DECK_NAME = "Amgi Smoke Test"

BASIC_MODEL_ID = 1607392319
MATHJAX_MODEL_ID = 1607392320
CLOZE_MODEL_ID = 998877665
AUDIO_MODEL_ID = 1607392321
CLOZE_AUDIO_MODEL_ID = 998877666
TYPEANS_MODEL_ID = 1607392322
LINK_MODEL_ID = 1607392323


def ensure_silence_mp3() -> str:
    """Generate a 1-second silent mp3 via ffmpeg if not already present."""
    os.makedirs(SILENCE_DIR, exist_ok=True)
    if os.path.exists(SILENCE_PATH):
        return SILENCE_PATH
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f", "lavfi",
            "-i", "anullsrc=r=44100:cl=mono",
            "-t", "1",
            "-q:a", "9",
            "-acodec", "libmp3lame",
            SILENCE_PATH,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return SILENCE_PATH


def make_models() -> dict:
    basic = genanki.Model(
        BASIC_MODEL_ID,
        "Amgi Smoke / Basic",
        fields=[{"name": "Front"}, {"name": "Back"}],
        templates=[
            {
                "name": "Card 1",
                "qfmt": "{{Front}}",
                "afmt": '{{FrontSide}}<hr id="answer">{{Back}}',
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; }",
    )

    mathjax = genanki.Model(
        MATHJAX_MODEL_ID,
        "Amgi Smoke / MathJax",
        fields=[{"name": "Front"}, {"name": "Back"}],
        templates=[
            {
                "name": "Card 1",
                "qfmt": "{{Front}}",
                "afmt": '{{FrontSide}}<hr id="answer">{{Back}}',
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; }",
    )

    cloze = genanki.Model(
        CLOZE_MODEL_ID,
        "Amgi Smoke / Cloze",
        fields=[{"name": "Text"}, {"name": "Back Extra"}],
        templates=[
            {
                "name": "Cloze",
                "qfmt": "{{cloze:Text}}",
                "afmt": "{{cloze:Text}}<br>{{Back Extra}}",
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; } .cloze { font-weight: bold; color: blue; }",
        model_type=genanki.Model.CLOZE,
    )

    audio = genanki.Model(
        AUDIO_MODEL_ID,
        "Amgi Smoke / Audio",
        fields=[{"name": "Front"}, {"name": "Back"}, {"name": "Sound"}],
        templates=[
            {
                "name": "Card 1",
                "qfmt": "{{Front}}<br>{{Sound}}",
                "afmt": '{{FrontSide}}<hr id="answer">{{Back}}',
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; }",
    )

    cloze_audio = genanki.Model(
        CLOZE_AUDIO_MODEL_ID,
        "Amgi Smoke / Cloze + Audio",
        fields=[{"name": "Text"}, {"name": "Sound"}],
        templates=[
            {
                "name": "Cloze",
                "qfmt": "{{cloze:Text}}<br>{{Sound}}",
                "afmt": "{{cloze:Text}}<br>{{Sound}}",
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; } .cloze { font-weight: bold; color: blue; }",
        model_type=genanki.Model.CLOZE,
    )

    typeans = genanki.Model(
        TYPEANS_MODEL_ID,
        "Amgi Smoke / Type-Answer",
        fields=[{"name": "Question"}, {"name": "Answer"}],
        templates=[
            {
                "name": "Card 1",
                "qfmt": "{{Question}}<br>{{type:Answer}}",
                "afmt": '{{Question}}<hr id="answer">{{type:Answer}}',
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; }",
    )

    link = genanki.Model(
        LINK_MODEL_ID,
        "Amgi Smoke / Link",
        fields=[{"name": "Front"}, {"name": "Back"}],
        templates=[
            {
                "name": "Card 1",
                "qfmt": "{{Front}}",
                "afmt": '{{FrontSide}}<hr id="answer">{{Back}}',
            },
        ],
        css=".card { font-family: -apple-system; font-size: 22px; text-align: center; } a { color: #007aff; }",
    )

    return {
        "basic": basic,
        "mathjax": mathjax,
        "cloze": cloze,
        "audio": audio,
        "cloze_audio": cloze_audio,
        "typeans": typeans,
        "link": link,
    }


def make_notes(models: dict) -> list:
    return [
        # 1. Plain text (baseline)
        genanki.Note(
            model=models["basic"],
            fields=["<b>Plain text card</b><br>What is 2 + 2?", "4"],
            tags=["smoke", "basic"],
        ),
        # 2. MathJax inline
        genanki.Note(
            model=models["mathjax"],
            fields=[
                "Pythagorean theorem: \\(a^2 + b^2 = c^2\\)<br>What is the formula in words?",
                "The square of the hypotenuse equals the sum of the squares of the other two sides.",
            ],
            tags=["smoke", "mathjax", "inline"],
        ),
        # 3. MathJax display block
        genanki.Note(
            model=models["mathjax"],
            fields=[
                "Evaluate the integral:<br>\\[ \\int_0^1 x \\, dx \\]",
                "\\[ \\int_0^1 x \\, dx = \\tfrac{1}{2} \\]",
            ],
            tags=["smoke", "mathjax", "display"],
        ),
        # 4. Cloze deletion
        genanki.Note(
            model=models["cloze"],
            fields=[
                "The capital of France is {{c1::Paris}}, and the capital of Japan is {{c2::Tokyo}}.",
                "Two simple geographic facts.",
            ],
            tags=["smoke", "cloze"],
        ),
        # 5. Standard + audio
        genanki.Note(
            model=models["audio"],
            fields=[
                "Audio playback test:",
                "If you tapped the play button and heard nothing (silence is expected), audio works.",
                "[sound:silence.mp3]",
            ],
            tags=["smoke", "audio", "standard"],
        ),
        # 6. Cloze + audio
        genanki.Note(
            model=models["cloze_audio"],
            fields=[
                "The {{c1::silent}} mp3 is one second long.",
                "[sound:silence.mp3]",
            ],
            tags=["smoke", "audio", "cloze"],
        ),
        # 7. Type-answer
        genanki.Note(
            model=models["typeans"],
            fields=[
                "What programming language is Amgi's iOS app written in?",
                "Swift",
            ],
            tags=["smoke", "type-answer"],
        ),
        # 8. Link card
        genanki.Note(
            model=models["link"],
            fields=[
                'Tap this link: <a href="https://example.com">https://example.com</a><br>'
                "(Should open in SFSafariViewController inside the app, not switch to Safari.)",
                "If the link opened in-app with a Done button at the top-left, link handling works.",
            ],
            tags=["smoke", "link"],
        ),
    ]


def main() -> int:
    silence = ensure_silence_mp3()
    models = make_models()
    notes = make_notes(models)

    deck = genanki.Deck(DECK_ID, DECK_NAME)
    for note in notes:
        deck.add_note(note)

    package = genanki.Package(deck, media_files=[silence])
    # genanki uses the basename of media files; rename in-package as silence.mp3
    package.write_to_file(OUT_PATH)

    print(f"Wrote {OUT_PATH}")
    print(f"  notes: {len(notes)}")
    print(f"  media: silence.mp3 ({os.path.getsize(silence)} bytes)")
    print()
    print("Import via the Amgi app: Settings → Import → choose .apkg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
