# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the ModelSim interface
"""


import unittest
from pathlib import Path
import os
from shutil import rmtree
from unittest import mock
from tests.common import set_env
from vunit.sim_if.modelsim import ModelSimInterface
from vunit.project import Project
from vunit.ostools import renew_path, write_file
from vunit.vhdl_standard import VHDL


class TestModelSimInterface(unittest.TestCase):
    """
    Test the ModelSim interface
    """

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_vhdl_2008(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file(
            "file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008")
        )
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vcom"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-2008",
            "-work",
            "lib",
            "file.vhd",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_vhdl_2002(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file(
            "file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2002")
        )
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vcom"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-2002",
            "-work",
            "lib",
            "file.vhd",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_vhdl_93(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file(
            "file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("93")
        )
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vcom"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-93",
            "-work",
            "lib",
            "file.vhd",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("modelsim.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vcom"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "custom",
            "flags",
            "-2008",
            "-work",
            "lib",
            "file.vhd",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_verilog(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vlog"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-work",
            "lib",
            "file.v",
            "-L",
            "lib",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_system_verilog(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vlog"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-sv",
            "-work",
            "lib",
            "file.sv",
            "-L",
            "lib",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("modelsim.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vlog"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "custom",
            "flags",
            "-work",
            "lib",
            "file.v",
            "-L",
            "lib",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file(
            "file.v", "lib", file_type="verilog", include_dirs=["include"]
        )
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        check_args = [
            str(Path(self.prefix_path) / "vlog"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-work",
            "lib",
            "file.v",
            "-L",
            "lib",
            "+incdir+include",
        ]
        check_output.assert_called_once_with(check_args, env=simif.get_env())

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, check_output):
        simif = ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file(
            "file.v", "lib", file_type="verilog", defines={"defname": "defval"}
        )
        simif.compile_project(project)
        process_args = [str(Path(self.prefix_path) / "vlib"), "-unix", "lib_path"]
        process.assert_called_once_with(process_args, env=simif.get_env())
        process_args = [
            str(Path(self.prefix_path) / "vlog"),
            "-quiet",
            "-modelsimini",
            str(Path(self.output_path) / "modelsim.ini"),
            "-work",
            "lib",
            "file.v",
            "-L",
            "lib",
            "+define+defname=defval",
        ]
        check_output.assert_called_once_with(process_args, env=simif.get_env())

    def _get_inis(self):
        return (
            str(Path(self.output_path) / "modelsim.ini"),
            str(Path(self.prefix_path) / ".." / "modelsim.ini"),
            str(Path(self.test_path) / "my_modelsim.ini"),
        )

    def test_copies_modelsim_ini_file_from_install(self):
        (modelsim_ini, installed_modelsim_ini, user_modelsim_ini) = self._get_inis()

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "installed")

    def test_copies_modelsim_ini_file_from_user(self):
        (modelsim_ini, installed_modelsim_ini, user_modelsim_ini) = self._get_inis()

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        with set_env(VUNIT_MODELSIM_INI=user_modelsim_ini):
            ModelSimInterface(
                prefix=self.prefix_path, output_path=self.output_path, persistent=False
            )

        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "user")

    def test_overwrites_modelsim_ini_file_from_install(self):
        (modelsim_ini, installed_modelsim_ini, user_modelsim_ini) = self._get_inis()

        with open(modelsim_ini, "w") as fptr:
            fptr.write("existing")

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        ModelSimInterface(
            prefix=self.prefix_path, output_path=self.output_path, persistent=False
        )
        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "installed")

    def test_overwrites_modelsim_ini_file_from_user(self):
        (modelsim_ini, installed_modelsim_ini, user_modelsim_ini) = self._get_inis()

        with open(modelsim_ini, "w") as fptr:
            fptr.write("existing")

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        with set_env(VUNIT_MODELSIM_INI=user_modelsim_ini):
            ModelSimInterface(
                prefix=self.prefix_path, output_path=self.output_path, persistent=False
            )

        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "user")

    def setUp(self):
        self.test_path = str(Path(__file__).parent / "test_modelsim_out")

        self.output_path = str(Path(self.test_path) / "modelsim")
        self.prefix_path = str(Path(self.test_path) / "prefix" / "bin")
        renew_path(self.test_path)
        renew_path(self.output_path)
        renew_path(self.prefix_path)
        installed_modelsim_ini = str(Path(self.prefix_path) / ".." / "modelsim.ini")
        write_file(installed_modelsim_ini, "[Library]")
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.test_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.test_path).exists():
            rmtree(self.test_path)
