# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
End to end test of the yavs interface against a fake yavs implementing the CLI contract
"""

import json
import os
import sys
import unittest
from pathlib import Path
from subprocess import call
from tests.common import check_report, create_tempdir

ROOT = Path(__file__).parent / "yavs"


@unittest.skipIf(sys.platform == "win32", "The fake yavs is a Python script without an .exe wrapper")
class TestYavsFake(unittest.TestCase):
    """
    Run a real run.py with VUNIT_SIMULATOR=yavs against the fake yavs
    """

    def _run(self, tempdir, *args, fail=""):
        """Run run.py against the fake yavs and return the exit code and the logged yavs calls"""
        log = tempdir / "yavs.log"
        env = dict(
            os.environ,
            VUNIT_SIMULATOR="yavs",
            VUNIT_YAVS_PATH=str(ROOT / "fake_bin"),
            FAKE_YAVS_LOG=str(log),
            FAKE_YAVS_FAIL=fail,
        )
        output_path = tempdir / "out with space"
        exit_code = call(
            [sys.executable, str(ROOT / "run.py"), "--clean", "-o", str(output_path), "-x", str(tempdir / "x.xml")]
            + list(args),
            env=env,
        )
        calls = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]
        return exit_code, calls

    def test_pass(self):
        with create_tempdir() as tempdir:
            exit_code, calls = self._run(tempdir, "lib.tb_yavs.test_pass", "lib.tb_yavs.test with, comma: and colon")
            self.assertEqual(exit_code, 0)
            check_report(
                str(tempdir / "x.xml"),
                [("passed", "lib.tb_yavs.test_pass"), ("passed", "lib.tb_yavs.test with, comma: and colon")],
            )

        self.assertTrue(any(cmd[0] == "analyze" and cmd[-1].endswith("tb_yavs.vhd") for cmd in calls))
        runs = [cmd for cmd in calls if cmd[0] == "run"]
        self.assertEqual(len(runs), 2)
        self.assertIn("tb_yavs.tb", runs[0])
        self.assertIn("--exit-severity=error", runs[0])

    def test_fail(self):
        with create_tempdir() as tempdir:
            exit_code, _ = self._run(tempdir, fail="test_fail")
            self.assertEqual(exit_code, 1)
            check_report(
                str(tempdir / "x.xml"),
                [
                    ("passed", "lib.tb_yavs.test_pass"),
                    ("passed", "lib.tb_yavs.test with, comma: and colon"),
                    ("failed", "lib.tb_yavs.test_fail"),
                ],
            )

    def test_elaborate_only(self):
        with create_tempdir() as tempdir:
            exit_code, calls = self._run(tempdir, "--elaborate", "lib.tb_yavs.test_pass")
            self.assertEqual(exit_code, 0)
        self.assertTrue(any(cmd[0] == "elab" for cmd in calls))
        self.assertFalse(any(cmd[0] == "run" for cmd in calls))
