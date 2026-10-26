#!/usr/bin/env python3
"""Cross-check MoonQR matrices against the Python `qrcode` reference.

The CLI is driven in ASCII mode with no quiet zone, and the resulting module
grid is compared cell by cell with `qrcode.QRCode.get_matrix()`. Every case
forces the version, EC level, mode and mask so both encoders must produce the
same symbol. Payloads are passed after `--` so that leading dashes are not
mistaken for options.
"""

from __future__ import annotations

import os
import random
import subprocess
import sys
from pathlib import Path

import qrcode
from qrcode.constants import (
    ERROR_CORRECT_H,
    ERROR_CORRECT_L,
    ERROR_CORRECT_M,
    ERROR_CORRECT_Q,
)
from qrcode.util import MODE_8BIT_BYTE, MODE_ALPHA_NUM, MODE_NUMBER, QRData

ROOT = Path(__file__).resolve().parents[2]
EC_LEVELS = {
    "L": ERROR_CORRECT_L,
    "M": ERROR_CORRECT_M,
    "Q": ERROR_CORRECT_Q,
    "H": ERROR_CORRECT_H,
}
MODES = {
    "numeric": (MODE_NUMBER, "0123456789"),
    "alphanumeric": (
        MODE_ALPHA_NUM,
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:",
    ),
    "byte": (MODE_8BIT_BYTE, "".join(chr(c) for c in range(32, 127))),
}
VERSIONS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]


def find_cli() -> Path:
    override = os.environ.get("MOONQR_CLI")
    candidates = []
    if override:
        candidates.append(Path(override))
    for profile in ("release", "debug"):
        for name in ("moonqr.exe", "moonqr"):
            candidates.append(
                ROOT / "_build" / "native" / profile / "build" / "cmd" / "moonqr" / name
            )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    sys.exit(
        "moonqr binary not found; build it with:\n"
        "  moon build cmd/moonqr --target native --release\n"
        "or set MOONQR_CLI to its path"
    )


def payload_length(mode: str, version: int) -> int:
    if mode == "numeric":
        return min(2 + version * version, 300)
    if mode == "alphanumeric":
        return min(1 + version * version // 2, 180)
    return min(1 + version * version // 4, 120)


def make_text(rng: random.Random, mode: str, length: int) -> str:
    return "".join(rng.choice(MODES[mode][1]) for _ in range(length))


def reference_matrix(text: str, version: int, ec: str, mode: str, mask: int):
    mode_id = MODES[mode][0]
    data = text.encode("utf-8") if mode == "byte" else text
    qr = qrcode.QRCode(
        version=version,
        error_correction=EC_LEVELS[ec],
        box_size=1,
        border=0,
        mask_pattern=mask,
    )
    qr.add_data(QRData(data, mode=mode_id))
    qr.make(fit=False)
    return qr.get_matrix()


def moon_matrix(
    cli: Path, text: str, version: int, ec: str, mode: str, mask: int
) -> list[list[bool]]:
    result = subprocess.run(
        [
            str(cli),
            "-v",
            str(version),
            "-l",
            ec,
            "-m",
            mode,
            "--mask",
            str(mask),
            "-q",
            "0",
            "-s",
            "1",
            "-f",
            "ascii",
            "--",
            text,
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    size = 4 * version + 17
    lines = result.stdout.splitlines()
    if len(lines) < size:
        raise AssertionError(f"expected {size} ASCII rows, got {len(lines)}")
    matrix = []
    for row in range(size):
        line = lines[row]
        if len(line) != size * 2:
            raise AssertionError(
                f"row {row}: expected {size * 2} characters, got {len(line)}"
            )
        matrix.append([line[col * 2 : col * 2 + 2] == "██" for col in range(size)])
    return matrix


def compare(case, cli: Path) -> None:
    label, text, version, ec, mode, mask = case
    expected = reference_matrix(text, version, ec, mode, mask)
    actual = moon_matrix(cli, text, version, ec, mode, mask)
    if len(expected) != len(actual):
        raise AssertionError(
            f"{label}: size mismatch {len(actual)} vs {len(expected)}"
        )
    for row, (expected_row, actual_row) in enumerate(zip(expected, actual)):
        for col, (want, got) in enumerate(zip(expected_row, actual_row)):
            if want != got:
                raise AssertionError(
                    f"{label}: mismatch at row {row}, col {col}: "
                    f"moon={got}, reference={want}"
                )


def main() -> int:
    cli = find_cli()
    rng = random.Random(20261026)
    cases = []
    for version in VERSIONS:
        for ec in EC_LEVELS:
            for mode in MODES:
                length = payload_length(mode, version)
                text = make_text(rng, mode, length)
                mask = rng.randrange(8)
                cases.append(
                    (f"v{version}-{ec}-{mode}-mask{mask}", text, version, ec, mode, mask)
                )
    for mask in range(8):
        cases.append((f"mask-{mask}", "MASK TEST", 2, "M", "alphanumeric", mask))
    for version, ec in [(5, "H"), (10, "M")]:
        cases.append(
            (
                f"utf8-v{version}-{ec}",
                "你好，世界",
                version,
                ec,
                "byte",
                3,
            )
        )
    cases.append(("leading-dash", "-QR-CODE-", 2, "M", "alphanumeric", 5))

    failures = 0
    for case in cases:
        try:
            compare(case, cli)
        except AssertionError as error:
            failures += 1
            print(f"FAIL {error}")
    print(f"{len(cases) - failures}/{len(cases)} matrices match the reference")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
