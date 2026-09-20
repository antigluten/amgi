#!/usr/bin/env python3
"""Dump the anki backend RPC dispatch table (service + method indices) from a
generated backend.rs (found under anki-bridge-rs/target/*/release/build/anki-*/out/).

Usage: python3 scripts/dump-dispatch-table.py <path-to-backend.rs>

Output lines: `<service_index>\t<service_name>\t<method_index>\t<method_name>` —
grep-friendly ground truth for verifying ServiceCatalog.swift / AnkiBackend.swift
constants after an anki-upstream bump.
"""
import re
import sys

src = open(sys.argv[1]).read()

# Top-level service table: `N => { ... self.run_<service>_method(...)`
services = {}  # name -> index
for m in re.finditer(r"(\d+)\s*=>\s*\{?\s*self\s*\.\s*run_([a-z0-9_]+)_method", src):
    services[m.group(2)] = int(m.group(1))

# Per-service bodies: fn run_<service>_method(...) { match method { ... } }
blocks = re.split(r"fn run_([a-z0-9_]+)_method\b", src)
NOISE = {"decode", "encode", "new"}
for name, body in zip(blocks[1::2], blocks[2::2]):
    if name not in services:
        continue
    # Split the body into match arms at `N => {`; each chunk after the first
    # belongs to the index that opened it.
    arms = re.split(r"\n\s*(\d+)\s*=>\s*\{", body)
    for midx, arm in zip(arms[1::2], arms[2::2]):
        # The dispatched method is the first `::method_name(` call that isn't
        # protobuf decode/encode plumbing.
        mname = next(
            (
                mm.group(1)
                for mm in re.finditer(r"::\s*([a-z][a-z0-9_]*)\s*\(", arm)
                if mm.group(1) not in NOISE
            ),
            "?",
        )
        print(f"{services[name]}\t{name}\t{midx}\t{mname}")
