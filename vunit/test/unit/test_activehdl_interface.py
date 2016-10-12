# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the ActiveHDL interface
"""


import unittest
from os.path import join, dirname, exists
import os
from shutil import rmtree
from vunit.activehdl_interface import ActiveHDLInterface
from vunit.test.mock_2or3 import mock
from vunit.project import Project
from vunit.ostools import renew_path, write_file


class TestActiveHDLInterface(unittest.TestCase):
    """
    Test the ActiveHDL interface
    """

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_vhdl(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-j',
             self.output_path,
             '-2008',
             '-work',
             'lib',
             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("activehdl.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with([join('prefix', 'vcom'),
                                             '-quiet',
                                             '-j',
                                             self.output_path,
                                             'custom',
                                             'flags',
                                             '-2008',
                                             '-work',
                                             'lib',
                                             'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_verilog(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-quiet',
                                             '-sv2k12',
                                             '-lc',
                                             library_cfg,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-l', 'lib'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("activehdl.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-quiet',
                                             '-sv2k12',
                                             '-lc',
                                             library_cfg,
                                             'custom',
                                             'flags',
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-l', 'lib'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-quiet',
                                             '-sv2k12',
                                             '-lc',
                                             library_cfg,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-l', 'lib',
                                             '+incdir+include'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    @mock.patch("vunit.activehdl_interface.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, run_command):
        library_cfg = join(self.output_path, "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix",
                                   library_cfg=library_cfg)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"], cwd=self.output_path)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"], cwd=self.output_path)
        run_command.assert_called_once_with([join('prefix', 'vlog'),
                                             '-quiet',
                                             '-sv2k12',
                                             '-lc',
                                             library_cfg,
                                             '-work',
                                             'lib',
                                             'file.v',
                                             '-l', 'lib',
                                             '+define+defname=defval'])

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_activehdl_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.output_path):
            rmtree(self.output_path)
