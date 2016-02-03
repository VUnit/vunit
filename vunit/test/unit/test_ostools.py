# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the os-dependent functionality wrappers
"""


from unittest import TestCase
from shutil import rmtree
from os.path import exists, dirname, join, abspath
import sys
from vunit.ostools import Process, renew_path


class TestOSTools(TestCase):
    """
    Test the os-dependent functionality wrappers
    """

    def setUp(self):
        self.tmp_dir = join(dirname(__file__), "test_ostools_tmp")
        renew_path(self.tmp_dir)

    def tearDown(self):
        if exists(self.tmp_dir):
            rmtree(self.tmp_dir)

    def make_file(self, file_name, contents):
        """
        Create a file in the temporary directory with contents
        Returns the absolute path to the file.
        """
        full_file_name = abspath(join(self.tmp_dir, file_name))
        with open(full_file_name, "w") as outfile:
            outfile.write(contents)
        return full_file_name

    def test_run_basic_subprocess(self):
        python_script = self.make_file("run_basic.py", r"""
from sys import stdout
stdout.write("foo\n")
stdout.write("bar\n")
""")

        output = []
        process = Process([sys.executable, python_script])
        process.consume_output(output.append)
        self.assertEqual(output, ["foo", "bar"])

    def test_run_error_subprocess(self):
        python_script = self.make_file("run_err.py", r"""
from sys import stdout
stdout.write("error\n")
exit(1)
""")
        process = Process([sys.executable, python_script])
        output = []
        self.assertRaises(Process.NonZeroExitCode,
                          process.consume_output, output.append)
        self.assertEqual(output, ["error"])

    def test_parses_stderr(self):
        python_script = self.make_file("run_err.py", r"""
from sys import stderr
stderr.write("error\n")
""")
        process = Process([sys.executable, python_script])
        output = []
        process.consume_output(output.append)
        self.assertEqual(output, ["error"])

    def test_output_is_parallel(self):
        python_script = self.make_file("run_timeout.py", r"""
from time import sleep
from sys import stdout
stdout.write("message\n")
stdout.flush()
sleep(1000)
""")

        process = Process([sys.executable, python_script])
        message = process.next_line()
        process.terminate()
        self.assertEqual(message, "message")

    def test_non_utf8_in_output(self):
        python_script = join(dirname(__file__), "non_utf8_printer.py")
        output = []
        process = Process([sys.executable, python_script])
        process.consume_output(output.append)
        self.assertEqual(output, [chr(0x87)])
