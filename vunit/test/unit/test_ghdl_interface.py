# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the GHDL interface
"""


import unittest
from vunit.ghdl_interface import GHDLInterface
from vunit.test.mock_2or3 import mock


class TestGHDLInterface(unittest.TestCase):
    """
    Test the GHDL interface
    """

    @mock.patch("vunit.ghdl_interface.GHDLInterface.find_executable")
    @mock.patch("vunit.ghdl_interface.GHDLInterface.determine_backend")
    def test_runtime_error_on_missing_gtkwave(self, determine_backend, find_executable):

        def determine_backend_side_effect():
            return "llvm"
        determine_backend.side_effect = determine_backend_side_effect

        executables = {}

        def find_executable_side_effect(name):
            return executables[name]

        find_executable.side_effect = find_executable_side_effect

        executables["gtkwave"] = ["path"]
        GHDLInterface()

        executables["gtkwave"] = []
        GHDLInterface()
        self.assertRaises(RuntimeError, GHDLInterface, gtkwave="ghw")

    @mock.patch('subprocess.check_output')
    def test_parses_llvm_backend(self, check_output):
        version = b"""\
GHDL 0.33dev (20141104) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 llvm code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend(), "llvm")

    @mock.patch('subprocess.check_output')
    def test_parses_mcode_backend(self, check_output):
        version = b"""\
GHDL 0.33dev (20141104) [Dunoon edition]
 Compiled with GNAT Version: 4.9.2
 mcode code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend(), "mcode")

    @mock.patch('subprocess.check_output')
    def test_parses_gcc_backend(self, check_output):
        version = b"""\
GHDL 0.31 (20140108) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 GCC back-end code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend(), "gcc")

    @mock.patch('subprocess.check_output')
    def test_assertion_on_unknown_backend(self, check_output):
        version = b"""\
GHDL 0.31 (20140108) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 xyz code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."""

        check_output.return_value = version
        self.assertRaises(AssertionError, GHDLInterface.determine_backend)
