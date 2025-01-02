# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test handling of Cadence Incisive .cds files
"""

import unittest
from unittest import mock
from vunit.sim_if.cds_file import CDSFile


class TestCDSFile(unittest.TestCase):
    """
    Test handling of Cadence Incisive .cds files
    """

    def test_parses_cds_file(self):
        cds = self._create_cds_file(CDS_FILE_CONTENTS)
        self.assertEqual(
            sorted(cds.items()),
            [
                ("lib", "./vunit_out/incisive/libraries/lib"),
                ("tb_uart_lib", "./vunit_out/incisive/libraries/tb_uart_lib"),
                ("uart_lib", "./vunit_out/incisive/libraries/uart_lib"),
                ("vunit_lib", "./vunit_out/incisive/libraries/vunit_lib"),
                ("worklib", "./vunit_out/incisive/libraries/worklib"),
            ],
        )

    def test_writes_cds_file(self):
        cds = self._create_cds_file(CDS_FILE_CONTENTS)
        self._check_written_as(cds, CDS_FILE_CONTENTS)

    def test_remove_and_add_libraries(self):
        cds = self._create_cds_file(CDS_FILE_CONTENTS)
        del cds["lib"]
        del cds["tb_uart_lib"]
        del cds["uart_lib"]
        del cds["vunit_lib"]
        del cds["worklib"]

        self._check_written_as(
            cds,
            """
#
# cds.lib: Defines the locations of compiled libraries.
#
softinclude $CDS_INST_DIR/tools/inca/files/cds.lib

""",
        )
        cds["foo"] = "bar"

        self._check_written_as(
            cds,
            """
#
# cds.lib: Defines the locations of compiled libraries.
#
softinclude $CDS_INST_DIR/tools/inca/files/cds.lib

define foo "bar"
""",
        )

    def test_ignores_case(self):
        cds = self._create_cds_file("DeFiNe foo bar")
        self.assertEqual(list(cds.keys()), ["foo"])
        self.assertEqual(cds["foo"], "bar")

    def test_unquotes_define(self):
        cds = self._create_cds_file('define foo "bar xyz"')
        self.assertEqual(cds["foo"], "bar xyz")

    def test_does_not_unquotes_define(self):
        cds = self._create_cds_file("define foo bar")
        self.assertEqual(cds["foo"], "bar")

    def test_quotes_define(self):
        cds = CDSFile()
        cds["foo"] = "bar xyz"
        self._check_written_as(cds, 'define foo "bar xyz"\n')

    @staticmethod
    def _create_cds_file(contents):
        """
        Create a CDSFile object with 'contents'
        """
        with mock.patch("vunit.sim_if.cds_file.read_file", autospec=True) as read_file:
            read_file.return_value = contents
            return CDSFile.parse("file_name")

    def _check_written_as(self, cds, contents):
        """
        Check that the CDSFile object writes the 'contents to the file
        """
        with mock.patch("vunit.sim_if.cds_file.write_file", autospec=True) as write_file:
            cds.write("filename")
            self.assertEqual(len(write_file.mock_calls), 1)
            args = write_file.mock_calls[0][1]
            self.assertEqual(args[0], "filename")
            self.assertEqual(args[1], contents)


CDS_FILE_CONTENTS = """
#
# cds.lib: Defines the locations of compiled libraries.
#
softinclude $CDS_INST_DIR/tools/inca/files/cds.lib

define lib "./vunit_out/incisive/libraries/lib"
define tb_uart_lib "./vunit_out/incisive/libraries/tb_uart_lib"
define uart_lib "./vunit_out/incisive/libraries/uart_lib"
define vunit_lib "./vunit_out/incisive/libraries/vunit_lib"
define worklib "./vunit_out/incisive/libraries/worklib"
"""
