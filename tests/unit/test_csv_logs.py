# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test csv log functionality
"""

import unittest
from shutil import rmtree
from os import remove
from pathlib import Path
from tempfile import NamedTemporaryFile, mkdtemp
from vunit.csv_logs import CsvLogs


class TestCsvLogs(unittest.TestCase):
    """
    Test csv log functionality
    """

    def setUp(self):
        self._log_files = []
        self._all_fields_dir = mkdtemp()
        self._few_fields_dir = mkdtemp()
        self._all_fields_files = str(Path(self._all_fields_dir) / "*.csv")
        self._few_fields_files = str(Path(self._few_fields_dir) / "*.csv")

        def make_log(directory, contents):
            """
            Make log
            """
            with NamedTemporaryFile("w+", delete=False, dir=directory, suffix=".csv") as file_obj:
                file_obj.write(contents)
                self._log_files.append(file_obj.name)

        make_log(
            self._all_fields_dir,
            "0,10 fs,info,bar.vhd,17,src1,This is an info entry.\n"
            "10,20 ps,failure,foo.vhd,42,src2,This is a failure entry.\n"
            "21,30 ns,error,foo.vhd,42,src2,This is an error entry.\n",
        )

        make_log(self._all_fields_dir, "")

        make_log(
            self._all_fields_dir,
            "4,100 fs,info,zoo.vhd,17,src3,This is an info entry.\n"
            "30,50 ns,failure,ying.vhd,42,src4,This is a failure entry.\n"
            "31,70 ns,error,yang.vhd,42,src5,This is an error entry.\n",
        )

        make_log(
            self._few_fields_dir,
            "0,10 fs,info,src1,This is an info entry.\n"
            "10,20 ps,failure,src2,This is a failure entry.\n"
            "21,30 ns,error,src2,This is an error entry.\n",
        )

        make_log(
            self._few_fields_dir,
            "4,100 fs,info,src3,This is an info entry.\n"
            "30,50 ns,failure,src4,This is a failure entry.\n"
            "31,70 ns,error,src5,This is an error entry.\n",
        )

    @staticmethod
    def _write_to_file_and_read_back_result(csv_logs):
        """
        Create a temporary file just to write the csv log results to it
        so that it can be read back and returned

        @TODO skip writing the file to disk and stub it
        """
        out_fp = NamedTemporaryFile(delete=False)
        out_fp.close()
        csv_logs.write(out_fp.name)

        with open(out_fp.name, "r") as fread:
            result = fread.read()
        remove(out_fp.name)

        return result

    def test_should_sort_several_csv_files(self):
        csvlogs = CsvLogs(self._all_fields_files)

        result = self._write_to_file_and_read_back_result(csvlogs)
        expected_result = """#,Time,Level,File,Line,Source,Message
0,10 fs,info,bar.vhd,17,src1,This is an info entry.
4,100 fs,info,zoo.vhd,17,src3,This is an info entry.
10,20 ps,failure,foo.vhd,42,src2,This is a failure entry.
21,30 ns,error,foo.vhd,42,src2,This is an error entry.
30,50 ns,failure,ying.vhd,42,src4,This is a failure entry.
31,70 ns,error,yang.vhd,42,src5,This is an error entry.
"""
        self.assertEqual(result, expected_result)

    def test_should_sort_single_csv_file(self):
        csvlogs = CsvLogs(self._log_files[0])

        result = self._write_to_file_and_read_back_result(csvlogs)
        expected_result = """#,Time,Level,File,Line,Source,Message
0,10 fs,info,bar.vhd,17,src1,This is an info entry.
10,20 ps,failure,foo.vhd,42,src2,This is a failure entry.
21,30 ns,error,foo.vhd,42,src2,This is an error entry.
"""
        self.assertEqual(result, expected_result)

    def test_should_sort_single_empty_csv_file(self):
        csvlogs = CsvLogs(self._log_files[1])

        result = self._write_to_file_and_read_back_result(csvlogs)
        expected_result = """#,Time,Level,File,Line,Source,Message
"""
        self.assertEqual(result, expected_result)

    def test_should_be_possible_to_add_csv_files(self):
        csvlogs = CsvLogs()
        for i in range(3):
            csvlogs.add(self._log_files[i])

        result = self._write_to_file_and_read_back_result(csvlogs)
        expected_result = """#,Time,Level,File,Line,Source,Message
0,10 fs,info,bar.vhd,17,src1,This is an info entry.
4,100 fs,info,zoo.vhd,17,src3,This is an info entry.
10,20 ps,failure,foo.vhd,42,src2,This is a failure entry.
21,30 ns,error,foo.vhd,42,src2,This is an error entry.
30,50 ns,failure,ying.vhd,42,src4,This is a failure entry.
31,70 ns,error,yang.vhd,42,src5,This is an error entry.
"""
        self.assertEqual(result, expected_result)

    def test_should_sort_several_csv_files_with_non_default_fields(self):
        csvlogs = CsvLogs(self._few_fields_files, ["#", "Time", "Level", "Source", "Message"])

        result = self._write_to_file_and_read_back_result(csvlogs)
        expected_result = """#,Time,Level,Source,Message
0,10 fs,info,src1,This is an info entry.
4,100 fs,info,src3,This is an info entry.
10,20 ps,failure,src2,This is a failure entry.
21,30 ns,error,src2,This is an error entry.
30,50 ns,failure,src4,This is a failure entry.
31,70 ns,error,src5,This is an error entry.
"""
        self.assertEqual(result, expected_result)

    def tearDown(self):
        rmtree(self._all_fields_dir)
        rmtree(self._few_fields_dir)
