# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the ModelSim interface
"""


import unittest
from os.path import join, dirname, exists
import os
from shutil import rmtree
from vunit.modelsim_interface import ModelSimInterface
from vunit.test.mock_2or3 import mock
from vunit.project import Project
from vunit.ostools import renew_path, write_file


class TestModelSimInterface(unittest.TestCase):
    """
    Test the ModelSim interface
    """

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_2008(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2008")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-2008',
             '-work',
             'lib',
             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_2002(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2002")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-2002',
             '-work',
             'lib',
             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_93(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="93")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-modelsimini',
             modelsim_ini,
             '-93',
             '-work',
             'lib',
             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("modelsim.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vcom'),
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             'custom',
                                             'flags',
                                             '-2008',
                                             '-work',
                                             'lib',
                                             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_vhdl_coverage(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  coverage="best",
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vcom'),
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             '+cover=best',
                                             '-2008',
                                             '-work',
                                             'lib',
                                             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-sv',
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-L', 'lib'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("modelsim.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-sv',
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             'custom',
                                             'flags',
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-L', 'lib'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_coverage(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  coverage="best",
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-sv',
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             '+cover=best',
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-L', 'lib'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-sv',
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-L', 'lib',
                                             '+incdir+include'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.modelsim_interface.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, run_command):
        write_file("modelsim.ini", """
[Library]
                   """)
        modelsim_ini = join(self.output_path, "modelsim.ini")
        simif = ModelSimInterface(prefix="prefix",
                                  modelsim_ini=modelsim_ini,
                                  persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_called_once_with([join("prefix", "vlib"), "-unix", "lib_path"])
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-sv',
                                             '-quiet',
                                             '-modelsimini',
                                             modelsim_ini,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-L', 'lib',
                                             '+define+defname=defval'])

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
