# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Verify that example projects run correctly
"""


import unittest
from os.path import join, dirname
from vunit.test.common import has_modelsim, check_report
from subprocess import check_call, call
import sys
from vunit import ROOT


@unittest.skipUnless(has_modelsim(), "Requires modelsim")
class TestExampleProjects(unittest.TestCase):
    """
    Verify that example projects run correctly
    """
    def setUp(self):
        self.output_path = join(dirname(__file__), "example_project_out")
        self.report_file = join(self.output_path, "xunit.xml")

    def test_uart_example_project(self):
        path = join(ROOT, "examples")
        check_call([sys.executable, join(path, "uart", "run.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])
        check_call([sys.executable, join(path, "uart", "run_with_preprocessing.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_logging_example_project(self):
        path = join(ROOT, "examples", "logging")
        check_call([sys.executable, join(path, "compile.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_check_example_project(self):
        path = join(ROOT, "examples", "check")
        check_call([sys.executable, join(path, "compile.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_generate_tests_example_project(self):
        path = join(ROOT, "examples", "generate_tests")
        check_call([sys.executable, join(path, "run.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_array_example_project(self):
        path = join(ROOT, "examples", "array")
        check_call([sys.executable, join(path, "run.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_user_guide_example_project(self):
        path = join(ROOT, "examples", "user_guide")
        retcode = call([sys.executable, join(path, "run.py"),
                        "--clean",
                        "--output-path=%s" % self.output_path,
                        "--xunit-xml=%s" % self.report_file])
        self.assertEqual(retcode, 1)
        check_report(self.report_file,
                     [("passed", "lib.tb_example"),
                      ("passed", "lib.tb_example_many.test_pass"),
                      ("failed", "lib.tb_example_many.test_fail")])

    def test_com_example_project(self):
        path = join(ROOT, "examples", "com")
        check_call([sys.executable, join(path, "run.py"),
                    "--clean",
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])
