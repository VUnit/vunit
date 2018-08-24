# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the ModelSim interface
"""


import unittest
from os.path import join, dirname, exists
import os
from shutil import rmtree
from vunit.modelsim_interface import ModelSimInterface
from vunit.test.mock_2or3 import mock
from vunit.test.common import set_env
from vunit.project import Project
from vunit.ostools import renew_path, write_file


class TestModelSimInterface(unittest.TestCase):
    """
    Test the ModelSim interface
    """

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_2008(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2008")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-2008',
             '-work',
             'lib',
             'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_2002(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2002")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-2002',
             '-work',
             'lib',
             'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_93(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="93")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-93',
             '-work',
             'lib',
             'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("modelsim.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vcom'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              'custom',
                                              'flags',
                                              '-2008',
                                              '-work',
                                              'lib',
                                              'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_coverage(self, process, check_output):
        for coverage_off in [False, True]:
            check_output.reset_mock()

            write_file("modelsim.ini", """
[Library]
                   """)
            modelsim_ini = join(self.output_path, "modelsim.ini")
            simif = ModelSimInterface(prefix="prefix",
                                      output_path=self.output_path,
                                      coverage="best",
                                      persistent=False)
            project = Project()
            project.add_library("lib", "lib_path")
            write_file("file.vhd", "")
            source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")

            if coverage_off:
                source_file.set_compile_option("disable_coverage", True)
                covargs = []
            else:
                covargs = ['+cover=best']

            simif.compile_project(project)
            process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
            check_output.assert_called_once_with([join('prefix', 'vcom'),
                                                  '-quiet',
                                                  '-modelsimini',
                                                  modelsim_ini] + covargs + [
                                                      '-2008',
                                                      '-work',
                                                      'lib',
                                                      'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-L', 'lib'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_system_verilog(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              '-sv',
                                              '-work',
                                              'lib',
                                              'file.sv',
                                              '-L', 'lib'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("modelsim.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              'custom',
                                              'flags',
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-L', 'lib'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_coverage(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  coverage="best",
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              '+cover=best',
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-L', 'lib'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-L', 'lib',
                                              '+incdir+include'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, check_output):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  output_path=self.output_path,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"], env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-modelsimini',
                                              modelsim_ini,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-L', 'lib',
                                              '+define+defname=defval'], env=simif.get_env())

    def test_copies_modelsim_ini_file_from_install(self):
        installed_path = join(self.output_path, "prefix")
        modelsim_ini = join(self.output_path, "modelsim", "modelsim.ini")
        installed_modelsim_ini = join(self.output_path, "modelsim.ini")
        user_modelsim_ini = join(self.output_path, "my_modelsim.ini")
        renew_path(installed_path)

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        ModelSimInterface(prefix=join(self.output_path, "prefix"),
                          output_path=join(self.output_path, "modelsim"),
                          persistent=False)
        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "installed")

    def test_copies_modelsim_ini_file_from_user(self):
        installed_path = join(self.output_path, "prefix")
        modelsim_ini = join(self.output_path, "modelsim", "modelsim.ini")
        installed_modelsim_ini = join(self.output_path, "modelsim.ini")
        user_modelsim_ini = join(self.output_path, "my_modelsim.ini")
        renew_path(installed_path)

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        with set_env(VUNIT_MODELSIM_INI=user_modelsim_ini):
            ModelSimInterface(prefix=join(self.output_path, "prefix"),
                              output_path=join(self.output_path, "modelsim"),
                              persistent=False)

        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "user")

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_modelsim_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.output_path):
            rmtree(self.output_path)
