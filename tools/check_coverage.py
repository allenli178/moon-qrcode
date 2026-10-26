#!/usr/bin/env python3
"""Fail if line coverage for the core encoder is below the NFR-9 threshold."""

import sys
import xml.etree.ElementTree as ET

THRESHOLD = 0.90
report = sys.argv[1] if len(sys.argv) > 1 else "coverage.xml"

root = ET.parse(report).getroot()
valid = 0
covered = 0
for cls in root.iter("class"):
    if not cls.get("filename", "").startswith("core/"):
        continue
    for line in cls.findall("./lines/line"):
        valid += 1
        if int(line.get("hits", "0")) > 0:
            covered += 1

if valid == 0:
    print("no core/ lines found in coverage report", file=sys.stderr)
    sys.exit(2)

rate = covered / valid
print(
    f"core coverage: {covered}/{valid} lines = {rate:.1%} "
    f"(threshold {THRESHOLD:.0%})",
)
sys.exit(0 if rate >= THRESHOLD else 1)
