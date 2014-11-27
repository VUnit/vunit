# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from unittest import TestCase

import subprocess
from vunit.ostools import Process

from shutil import rmtree
from os import makedirs
from os.path import exists, dirname, join, abspath
from time import time

class TestOSTools(TestCase):

    def setUp(self):
        self.tmp_dir = join(dirname(__file__), "test_ostools_tmp")
        if exists(self.tmp_dir):
            rmtree(self.tmp_dir)
        makedirs(self.tmp_dir)

    def tearDown(self):
        if exists(self.tmp_dir):
            rmtree(self.tmp_dir)

    def make_file(self, file_name, contents):
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
        process = Process(["python", python_script])
        process.consume_output(lambda line: output.append(line))
        self.assertEqual(output, ["foo", "bar"])
        self.assertEqual(process.output, "foo\nbar\n")

    def test_run_error_subprocess(self):
        python_script = self.make_file("run_err.py", r"""
from sys import stdout
stdout.write("error\n")
exit(1)
""")
        process = Process(["python", python_script])
        output = []
        self.assertRaises(Process.NonZeroExitCode,
                          process.consume_output, lambda line: output.append(line))
        self.assertEqual(output, ["error"])
        self.assertEqual(process.output, "error\n")

    def test_parses_stderr(self):
        python_script = self.make_file("run_err.py", r"""
from sys import stderr
stderr.write("error\n")
""")
        process = Process(["python", python_script])
        output = []
        process.consume_output(lambda line: output.append(line))
        self.assertEqual(output, ["error"])
        self.assertEqual(process.output, "error\n")


    def test_output_is_parallel(self):
        python_script = self.make_file("run_timeout.py", r"""
from time import sleep
from sys import stdout
stdout.write("message\n")
stdout.flush()
sleep(1000)
""")

        process = Process(["python", python_script])
        message = process._next()
        process.terminate()
        self.assertEqual(message, "message")

