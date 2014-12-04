# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import join, dirname
from common import has_modelsim, check_report
from subprocess import check_call, call
import sys

@unittest.skipUnless(has_modelsim(), "Requires modelsim")
class TestExampleProjects(unittest.TestCase):
    def setUp(self):
        self.output_path = join(dirname(__file__), "example_project_out")
        self.report_file = join(self.output_path, "xunit.xml")

    def test_uart_example_project(self):
        path = join(dirname(__file__), "..", "examples")
        check_call([sys.executable, join(path, "uart", "run.py"), 
                    "--clean", 
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])
        check_call([sys.executable, join(path, "uart", "run_with_location_preprocessing.py"), 
                    "--clean", 
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_logging_example_project(self):
        path = join(dirname(__file__), "..", "examples", "logging")
        check_call([sys.executable, join(path, "compile.py"),
                    "--clean", 
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_check_example_project(self):
        path = join(dirname(__file__), "..", "examples", "check")
        check_call([sys.executable, join(path, "compile.py"),
                    "--clean", 
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_generate_tests_example_project(self):
        path = join(dirname(__file__), "..", "examples", "generate_tests")
        check_call([sys.executable, join(path, "run.py"),
                    "--clean", 
                    "--output-path=%s" % self.output_path,
                    "--xunit-xml=%s" % self.report_file])

    def test_user_guide_example_project(self):
        path = join(dirname(__file__), "..", "examples", "user_guide")
        retcode = call([sys.executable, join(path, "run.py"),
                        "--clean", 
                        "--output-path=%s" % self.output_path,
                        "--xunit-xml=%s" % self.report_file])
        self.assertEqual(retcode, 1)
        check_report(self.report_file, 
                     [("passed", "lib.tb_example"),
                      ("passed", "lib.tb_example_many.test_pass"),
                      ("failed", "lib.tb_example_many.test_fail")])
