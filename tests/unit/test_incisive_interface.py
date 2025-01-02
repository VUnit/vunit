# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods, too-many-lines

"""
Test the Incisive interface
"""


import unittest
from pathlib import Path
import os
from shutil import rmtree
from unittest import mock
from vunit.sim_if.incisive import IncisiveInterface
from vunit.project import Project
from vunit.ostools import renew_path, write_file, read_file
from vunit.test.bench import Configuration
from vunit.vhdl_standard import VHDL
from tests.common import create_tempdir
from tests.unit.test_test_bench import Entity


class TestIncisiveInterface(unittest.TestCase):
    """
    Test the Incisive interface
    """

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_vhdl_2008(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008"))
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_vhdl_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-v200x -extv200x",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_vhdl_file_lib.log"),
                "-quiet",
                '-nclibdirname "."',
                "-makelib lib_path",
                '"file.vhd"',
                "-endlib",
            ],
        )

        self.assertEqual(
            read_file(str(Path(self.output_path) / "cds.lib")),
            """\
## cds.lib: Defines the locations of compiled libraries.
softinclude cds_root_irun/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define lib "lib_path"
define work "%s/libraries/work"
"""
            % self.output_path,
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_vhdl_2002(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2002"))
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_vhdl_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-v200x -extv200x",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_vhdl_file_lib.log"),
                "-quiet",
                '-nclibdirname "."',
                "-makelib lib_path",
                '"file.vhd"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_vhdl_93(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("93"))
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_vhdl_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-v93",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_vhdl_file_lib.log"),
                "-quiet",
                '-nclibdirname "."',
                "-makelib lib_path",
                '"file.vhd"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_vhdl_extra_flags(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("incisive.irun_vhdl_flags", ["custom", "flags"])
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_vhdl_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-v200x -extv200x",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_vhdl_file_lib.log"),
                "-quiet",
                "custom",
                "flags",
                '-nclibdirname "."',
                "-makelib lib_path",
                '"file.vhd"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_vhdl_hdlvar(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path, hdlvar="custom_hdlvar")
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_vhdl_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-v200x -extv200x",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-hdlvar "custom_hdlvar"',
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_vhdl_file_lib.log"),
                "-quiet",
                '-nclibdirname "."',
                "-makelib lib_path",
                '"file.vhd"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_verilog(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                '-nclibdirname "."',
                "-makelib lib",
                '"file.v"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_system_verilog(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                '-nclibdirname "."',
                "-makelib lib",
                '"file.sv"',
                "-endlib",
            ],
        )

        self.assertEqual(
            read_file(str(Path(self.output_path) / "cds.lib")),
            """\
## cds.lib: Defines the locations of compiled libraries.
softinclude cds_root_irun/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define lib "lib_path"
define work "%s/libraries/work"
"""
            % self.output_path,
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_verilog_extra_flags(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("incisive.irun_verilog_flags", ["custom", "flags"])
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                "custom",
                "flags",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                '-nclibdirname "."',
                "-makelib lib",
                '"file.v"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_verilog_include(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "include"',
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                '-nclibdirname "."',
                "-makelib lib",
                '"file.v"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_verilog_define(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines=dict(defname="defval"))
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                "-define defname=defval",
                '-nclibdirname "."',
                "-makelib lib",
                '"file.v"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    def test_compile_project_verilog_hdlvar(self, check_output, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path, hdlvar="custom_hdlvar")
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines=dict(defname="defval"))
        simif.compile_project(project)
        args_file = str(Path(self.output_path) / "irun_compile_verilog_file_lib.args")
        check_output.assert_called_once_with([str(Path("prefix") / "irun"), "-f", args_file], env=simif.get_env())
        self.assertEqual(
            read_file(args_file).splitlines(),
            [
                "-compile",
                "-nocopyright",
                "-licqueue",
                "-nowarn UEXPSC",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-work work",
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-hdlvar "custom_hdlvar"',
                '-log "%s"' % str(Path(self.output_path) / "irun_compile_verilog_file_lib.log"),
                "-quiet",
                '-incdir "cds_root_irun/tools/spectre/etc/ahdl/"',
                "-define defname=defval",
                '-nclibdirname "."',
                "-makelib lib",
                '"file.v"',
                "-endlib",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    def test_create_cds_lib(self, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        IncisiveInterface(prefix="prefix", output_path=self.output_path)
        self.assertEqual(
            read_file(str(Path(self.output_path) / "cds.lib")),
            """\
## cds.lib: Defines the locations of compiled libraries.
softinclude cds_root_irun/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define work "%s/libraries/work"
"""
            % self.output_path,
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    def test_create_cds_lib_virtuoso(self, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = "cds_root_virtuoso"
        IncisiveInterface(prefix="prefix", output_path=self.output_path)
        self.assertEqual(
            read_file(str(Path(self.output_path) / "cds.lib")),
            """\
## cds.lib: Defines the locations of compiled libraries.
softinclude cds_root_irun/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
define basic "cds_root_virtuoso/tools/dfII/etc/cdslib/basic"
define work "%s/libraries/work"
"""
            % self.output_path,
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_vhdl(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)

        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.sim_if.check_output", autospec=True, return_value="") as dummy:
            simif.compile_project(project)

        config = make_config()
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

        self.assertEqual(
            read_file(elaborate_args_file).splitlines(),
            [
                "-elaborate",
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_elaborate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +r",
                '-input "@run"',
                "-top lib.ent:arch",
            ],
        )

        self.assertEqual(
            read_file(simulate_args_file).splitlines(),
            [
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_simulate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +r",
                '-input "@run"',
                "-top lib.ent:arch",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_verilog(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)

        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.sim_if.check_output", autospec=True, return_value="") as dummy:
            simif.compile_project(project)

        config = make_config(verilog=True)
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

        self.assertEqual(
            read_file(elaborate_args_file).splitlines(),
            [
                "-elaborate",
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_elaborate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +r",
                '-input "@run"',
                "-top lib.modulename:sv",
            ],
        )

        self.assertEqual(
            read_file(simulate_args_file).splitlines(),
            [
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_simulate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +r",
                '-input "@run"',
                "-top lib.modulename:sv",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_extra_flags(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        config = make_config(sim_options={"incisive.irun_sim_flags": ["custom", "flags"]})
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

        args = read_file(elaborate_args_file).splitlines()
        self.assertIn("custom", args)
        self.assertIn("flags", args)

        args = read_file(simulate_args_file).splitlines()
        self.assertIn("custom", args)
        self.assertIn("flags", args)

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_generics_and_parameters(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        config = make_config(verilog=True, generics={"genstr": "genval", "genint": 1, "genbool": True})
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

        for args_file in [elaborate_args_file, simulate_args_file]:
            args = read_file(args_file).splitlines()
            self.assertIn('-gpg "modulename.genstr => \\"genval\\""', args)
            self.assertIn('-gpg "modulename.genint => 1"', args)
            self.assertIn('-gpg "modulename.genbool => \\"True\\""', args)

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_hdlvar(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path, hdlvar="custom_hdlvar")
        config = make_config()
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

        for args_file in [elaborate_args_file, simulate_args_file]:
            args = read_file(args_file).splitlines()
            self.assertIn('-hdlvar "custom_hdlvar"', args)

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_elaborate(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        config = make_config(verilog=True)
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config, elaborate_only=True))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                )
            ]
        )

        self.assertEqual(
            read_file(elaborate_args_file).splitlines(),
            [
                "-elaborate",
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_elaborate.log"),
                "-quiet",
                "-access +r",
                '-input "@run"',
                "-top lib.modulename:sv",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=False)
    def test_elaborate_fail(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        config = make_config()
        self.assertFalse(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                )
            ]
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, side_effect=[True, False])
    def test_simulate_fail(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None
        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
        config = make_config()
        self.assertFalse(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    @mock.patch("vunit.sim_if.incisive.run_command", autospec=True, return_value=True)
    def test_simulate_gui(self, run_command, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None

        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")

        simif = IncisiveInterface(prefix="prefix", output_path=self.output_path, gui=True)
        with mock.patch("vunit.sim_if.check_output", autospec=True, return_value="") as dummy:
            simif.compile_project(project)
        config = make_config()
        self.assertTrue(simif.simulate("suite_output_path", "test_suite_name", config))
        elaborate_args_file = str(Path("suite_output_path") / simif.name / "irun_elaborate.args")
        simulate_args_file = str(Path("suite_output_path") / simif.name / "irun_simulate.args")
        run_command.assert_has_calls(
            [
                mock.call(
                    [
                        str(Path("prefix") / "irun"),
                        "-f",
                        Path(elaborate_args_file).name,
                    ],
                    cwd=str(Path(elaborate_args_file).parent),
                    env=simif.get_env(),
                ),
                mock.call(
                    [str(Path("prefix") / "irun"), "-f", Path(simulate_args_file).name],
                    cwd=str(Path(simulate_args_file).parent),
                    env=simif.get_env(),
                ),
            ]
        )
        self.assertEqual(
            read_file(elaborate_args_file).splitlines(),
            [
                "-elaborate",
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_elaborate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +rwc",
                "-gui",
                "-top lib.ent:arch",
            ],
        )

        self.assertEqual(
            read_file(simulate_args_file).splitlines(),
            [
                "-nocopyright",
                "-licqueue",
                "-errormax 10",
                "-nowarn WRMNZD",
                "-nowarn DLCPTH",
                "-nowarn DLCVAR",
                "-ncerror EVBBOL",
                "-ncerror EVBSTR",
                "-ncerror EVBNAT",
                "-work work",
                '-nclibdirname "%s"' % str(Path(self.output_path) / "libraries"),
                '-cdslib "%s"' % str(Path(self.output_path) / "cds.lib"),
                '-log "%s"' % str(Path("suite_output_path") / simif.name / "irun_simulate.log"),
                "-quiet",
                '-reflib "lib_path"',
                "-access +rwc",
                "-gui",
                "-top lib.ent:arch",
            ],
        )

    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_virtuoso")
    @mock.patch("vunit.sim_if.incisive.IncisiveInterface.find_cds_root_irun")
    def test_configuration_and_entity_selection(self, find_cds_root_irun, find_cds_root_virtuoso):
        find_cds_root_irun.return_value = "cds_root_irun"
        find_cds_root_virtuoso.return_value = None

        with create_tempdir() as tempdir:
            design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
            design_unit.generic_names = ["runner_cfg"]
            config = Configuration("name", design_unit, vhdl_configuration_name="cfg")
            simif = IncisiveInterface(prefix="prefix", output_path=self.output_path)
            self.assertEqual(simif._select_vhdl_top(config), "cfg")  # pylint: disable=protected-access
            config = Configuration("name", design_unit)
            self.assertEqual(simif._select_vhdl_top(config), "lib.tb_entity:arch")  # pylint: disable=protected-access

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_incisive_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)


def make_config(sim_options=None, generics=None, verilog=False):
    """
    Utility to reduce boiler plate in tests
    """
    cfg = mock.Mock(spec=Configuration)
    cfg.library_name = "lib"

    if verilog:
        cfg.entity_name = "modulename"
        cfg.architecture_name = None
    else:
        cfg.entity_name = "ent"
        cfg.architecture_name = "arch"

    cfg.sim_options = {} if sim_options is None else sim_options
    cfg.generics = {} if generics is None else generics
    cfg.vhdl_configuration_name = None
    return cfg
