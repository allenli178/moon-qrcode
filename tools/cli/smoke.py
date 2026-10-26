#!/usr/bin/env python3
"""Smoke tests for the native moonqr CLI, including stdin and JSON output."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD_DIR = ROOT / "_build" / "native" / "release" / "build" / "cmd" / "moonqr"


def find_binary() -> Path:
    override = os.environ.get("MOONQR_BIN")
    if override:
        return Path(override)
    for name in ("moonqr", "moonqr.exe"):
        candidate = BUILD_DIR / name
        if candidate.is_file():
            return candidate
    raise SystemExit(
        "moonqr binary not found; run "
        "`moon build cmd/moonqr --target native --release` first "
        "or set MOONQR_BIN"
    )


BINARY = find_binary()


def run_cli(args: list[str], stdin: bytes | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(BINARY), *args],
        input=stdin,
        capture_output=True,
    )


def text_of(data: bytes) -> str:
    return data.decode("utf-8", errors="replace")


class StdinTests(unittest.TestCase):
    def assert_matches_argument(self, payload: str, options: list[str]) -> None:
        from_argument = run_cli([payload, *options])
        from_stdin = run_cli(["-", *options], stdin=(payload + "\n").encode())
        self.assertEqual(from_argument.returncode, 0, text_of(from_argument.stderr))
        self.assertEqual(from_stdin.returncode, 0, text_of(from_stdin.stderr))
        self.assertEqual(from_stdin.stdout, from_argument.stdout)

    def test_ascii(self) -> None:
        self.assert_matches_argument("HELLO WORLD", ["-q", "0"])

    def test_svg(self) -> None:
        self.assert_matches_argument("https://moonbitlang.com", ["-f", "svg", "-q", "2"])

    def test_utf8(self) -> None:
        self.assert_matches_argument("你好，世界", ["-q", "0"])

    def test_options(self) -> None:
        self.assert_matches_argument(
            "forced options",
            ["-l", "H", "--min-version", "5", "--max-version", "5", "--mask", "3", "-q", "0"],
        )

    def test_trailing_newlines_are_stripped(self) -> None:
        stripped = run_cli(["payload", "-q", "0"])
        padded = run_cli(["-", "-q", "0"], stdin=b"payload\n\n\r\n")
        self.assertEqual(padded.returncode, 0, text_of(padded.stderr))
        self.assertEqual(padded.stdout, stripped.stdout)

    def test_empty_stdin_fails(self) -> None:
        result = run_cli(["-"], stdin=b"")
        self.assertEqual(result.returncode, 1)
        self.assertIn("input is empty", text_of(result.stderr))
        self.assertEqual(result.stdout, b"")

    def test_invalid_utf8_fails(self) -> None:
        result = run_cli(["-"], stdin=b"\xff\xfe")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not valid UTF-8", text_of(result.stderr))

    def test_stdin_to_output_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "code.svg"
            from_stdin = run_cli(["-", "-q", "2", "-o", str(target)], stdin=b"file output\n")
            self.assertEqual(from_stdin.returncode, 0, text_of(from_stdin.stderr))
            self.assertTrue(target.is_file())
            from_argument = run_cli(["file output", "-q", "2", "-f", "svg"])
            self.assertEqual(target.read_bytes(), from_argument.stdout)


class JsonTests(unittest.TestCase):
    def test_json_metadata_and_modules(self) -> None:
        result = run_cli(["HELLO WORLD", "-l", "L", "--json"])
        self.assertEqual(result.returncode, 0, text_of(result.stderr))
        data = json.loads(result.stdout)
        self.assertEqual(data["version"], 1)
        self.assertEqual(data["ecLevel"], "L")
        self.assertGreaterEqual(data["mask"], 0)
        self.assertLessEqual(data["mask"], 7)
        self.assertEqual(data["size"], 21)
        rows = data["modules"]
        self.assertEqual(len(rows), 21)
        for row in rows:
            self.assertEqual(len(row), 21)
            self.assertLessEqual(set(row), {"0", "1"})
        self.assertEqual(rows[0][:7], "1111111")
        self.assertEqual(rows[0][-7:], "1111111")

    def test_json_flag_and_format_agree(self) -> None:
        flag = run_cli(["HELLO", "--json"])
        fmt = run_cli(["HELLO", "-f", "json"])
        self.assertEqual(flag.returncode, 0, text_of(flag.stderr))
        self.assertEqual(flag.stdout, fmt.stdout)

    def test_json_output_file_by_extension(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "code.json"
            result = run_cli(["HELLO", "-o", str(target)])
            self.assertEqual(result.returncode, 0, text_of(result.stderr))
            data = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(data["size"], 21)


class ArgumentTests(unittest.TestCase):
    def test_double_dash_allows_leading_dash_payload(self) -> None:
        payload = "-dash-payload"
        expected = run_cli(["-", "-q", "0"], stdin=payload.encode())
        actual = run_cli(["-q", "0", "--", payload])
        self.assertEqual(actual.returncode, 0, text_of(actual.stderr))
        self.assertEqual(actual.stdout, expected.stdout)

    def test_double_dash_requires_payload(self) -> None:
        result = run_cli(["--"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing payload", text_of(result.stderr))

    def test_diagnostics_go_to_stderr(self) -> None:
        unknown = run_cli(["payload", "--bogus"])
        self.assertEqual(unknown.returncode, 1)
        self.assertEqual(unknown.stdout, b"")
        self.assertIn("unknown option", text_of(unknown.stderr))

        empty = run_cli([""])
        self.assertEqual(empty.returncode, 1)
        self.assertEqual(empty.stdout, b"")
        self.assertIn("input is empty", text_of(empty.stderr))

    def test_invalid_json_format_is_reported(self) -> None:
        result = run_cli(["HELLO", "-f", "yaml"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("invalid format", text_of(result.stderr))


class VersionTests(unittest.TestCase):
    def test_short_and_long_flags_agree(self) -> None:
        short = run_cli(["-V"])
        long = run_cli(["--cli-version"])
        self.assertEqual(short.returncode, 0)
        self.assertEqual(short.stdout, long.stdout)
        self.assertRegex(text_of(short.stdout), r"^moonqr \d+\.\d+\.\d+")

    def test_help_mentions_stdin_and_json(self) -> None:
        result = run_cli(["--help"])
        self.assertEqual(result.returncode, 0)
        help_text = text_of(result.stdout)
        self.assertIn("stdin", help_text)
        self.assertIn("--json", help_text)
        self.assertIn("--", help_text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
