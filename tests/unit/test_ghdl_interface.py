# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the GHDL interface
"""

import unittest
from pathlib import Path
import os
from shutil import rmtree
from unittest import mock
from tests.unit.test_test_bench import Entity
from vunit.sim_if.ghdl import GHDLInterface
from vunit.project import Project
from vunit.ostools import renew_path, write_file
from vunit.exceptions import CompileError
from vunit.configuration import Configuration
from vunit.vhdl_standard import VHDL


class TestGHDLInterface(unittest.TestCase):
    """
    Test the GHDL interface
    """

    @mock.patch("subprocess.check_output", autospec=True)
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
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "llvm")

        version = b"""\
GHDL 3.0.0-dev (2.0.0.r1369.gf04182410) [Dunoon edition]
 Compiled with GNAT Version: 12.2.0
 llvm 15.0.7 code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2022 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""

        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "llvm")

    @mock.patch("subprocess.check_output", autospec=True)
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
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "mcode")

        version = b"""\
GHDL 5.0.0-dev (4.0.0.r9.g77785e49e) [Dunoon edition]
 Compiled with GNAT Version: 10.5.0
 static elaboration, mcode JIT code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2024 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "mcode")

    @mock.patch("subprocess.check_output", autospec=True)
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
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "gcc")

        version = b"""\
GHDL 3.0.0-dev (2.0.0.r1369.gf04182410) [Dunoon edition]
 Compiled with GNAT Version: 10.4.0
 GCC 11.2.0 code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2022 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "gcc")

    @mock.patch("subprocess.check_output", autospec=True)
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
        self.assertRaises(AssertionError, GHDLInterface.determine_backend, "prefix")

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")  # pylint: disable=no-self-use
    def test_compile_project_2008(self, check_output):
        simif = GHDLInterface(prefix="prefix", output_path="")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008"))
        simif.compile_project(project)
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "ghdl"),
                "-a",
                "--workdir=lib_path",
                "--work=lib",
                "--std=08",
                "-Plib_path",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")  # pylint: disable=no-self-use
    def test_compile_project_2002(self, check_output):
        simif = GHDLInterface(prefix="prefix", output_path="")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2002"))
        simif.compile_project(project)
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "ghdl"),
                "-a",
                "--workdir=lib_path",
                "--work=lib",
                "--std=02",
                "-Plib_path",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")  # pylint: disable=no-self-use
    def test_compile_project_93(self, check_output):
        simif = GHDLInterface(prefix="prefix", output_path="")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("93"))
        simif.compile_project(project)
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "ghdl"),
                "-a",
                "--workdir=lib_path",
                "--work=lib",
                "--std=93",
                "-Plib_path",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")  # pylint: disable=no-self-use
    def test_compile_project_extra_flags(self, check_output):
        simif = GHDLInterface(prefix="prefix", output_path="")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("ghdl.a_flags", ["custom", "flags"])
        simif.compile_project(project)
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "ghdl"),
                "-a",
                "--workdir=lib_path",
                "--work=lib",
                "--std=08",
                "-Plib_path",
                "custom",
                "flags",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    def test_elaborate_e_project(self):
        design_unit = Entity("tb_entity", file_name=str(Path("tempdir") / "file.vhd"))
        design_unit.original_file_name = str(Path("tempdir") / "other_path" / "original_file.vhd")
        design_unit.generic_names = ["runner_cfg", "tb_path"]

        config = Configuration("name", design_unit, sim_options={"ghdl.elab_e": True})

        simif = GHDLInterface(prefix="prefix", output_path="")
        simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access
        simif._project = Project()  # pylint: disable=protected-access
        simif._project.add_library("lib", "lib_path")  # pylint: disable=protected-access

        self.assertEqual(
            simif._get_command(  # pylint: disable=protected-access
                config, str(Path("output_path") / "ghdl"), True, True, "tb_entity", None
            ),
            [
                str(Path("prefix") / "ghdl"),
                "-e",
                "--std=08",
                "--work=lib",
                "--workdir=lib_path",
                "-Plib_path",
                "-o",
                str(Path("output_path") / "ghdl" / "tb_entity-arch"),
                "tb_entity",
                "arch",
            ],
        )

    def test_compile_project_verilog_error(self):
        simif = GHDLInterface(prefix="prefix", output_path="")
        write_file("file.v", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.v", "lib", file_type="verilog")
        self.assertRaises(CompileError, simif.compile_project, project)

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_ghdl_interface_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)
