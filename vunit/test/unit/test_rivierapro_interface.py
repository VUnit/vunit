# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the RivieraPro interface
"""


import unittest
from os.path import join, dirname, exists
import os
from itertools import product
from shutil import rmtree
from vunit.rivierapro_interface import RivieraProInterface
from vunit.test.mock_2or3 import mock
from vunit.project import Project
from vunit.ostools import renew_path, write_file


class TestRivieraProInterface(unittest.TestCase):
    """
    Test the RivieraPro interface
    """

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_vhdl(self, process, check_output):
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl")
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with(
            [join('prefix', 'vcom'),
             '-quiet',
             '-j',
             self.output_path,
             '-2008',
             '-work',
             'lib',
             'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, check_output):
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("rivierapro.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vcom'),
                                              '-quiet',
                                              '-j',
                                              self.output_path,
                                              'custom',
                                              'flags',
                                              '-2008',
                                              '-work',
                                              'lib',
                                              'file.vhd'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_verilog(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-lc',
                                              library_cfg,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-l', 'lib'],
                                             env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_system_verilog(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-lc',
                                              library_cfg,
                                              '-sv2k12',
                                              '-work',
                                              'lib',
                                              'file.sv',
                                              '-l', 'lib'],
                                             env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("rivierapro.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-lc',
                                              library_cfg,
                                              'custom',
                                              'flags',
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-l', 'lib'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=None)
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-lc',
                                              library_cfg,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-l', 'lib',
                                              '+incdir+include'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")
        simif = RivieraProInterface(prefix="prefix",
                                    output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                cwd=self.output_path, env=simif.get_env())
        process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                   cwd=self.output_path, env=simif.get_env())
        check_output.assert_called_once_with([join('prefix', 'vlog'),
                                              '-quiet',
                                              '-lc',
                                              library_cfg,
                                              '-work',
                                              'lib',
                                              'file.v',
                                              '-l', 'lib',
                                              '+define+defname=defval'], env=simif.get_env())

    @mock.patch("vunit.simulator_interface.check_output", autospec=True, return_value="")
    @mock.patch("vunit.rivierapro_interface.Process", autospec=True)
    def test_compile_project_coverage(self, process, check_output):
        library_cfg = join(self.output_path, "library.cfg")

        for file_type, coverage_off in product(["vhdl", "verilog"], [False, True]):
            check_output.reset_mock()

            simif = RivieraProInterface(prefix="prefix",
                                        output_path=self.output_path,
                                        coverage="bes")

            project = Project()
            project.add_library("lib", "lib_path")

            if file_type == "vhdl":
                file_name = "file.vhd"
            else:
                file_name = "file.v"

            write_file(file_name, "")
            source_file = project.add_source_file(file_name, "lib", file_type=file_type)

            if coverage_off:
                covargs = []
                source_file.set_compile_option("disable_coverage", True)
            else:
                covargs = ['-coverage', 'bes']

            simif.compile_project(project)
            process.assert_any_call([join("prefix", "vlib"), "lib", "lib_path"],
                                    cwd=self.output_path, env=simif.get_env())
            process.assert_called_with([join("prefix", "vmap"), "lib", "lib_path"],
                                       cwd=self.output_path, env=simif.get_env())

            if file_type == "vhdl":
                check_output.assert_called_once_with(
                    [join('prefix', 'vcom'),
                     '-quiet',
                     '-j',
                     self.output_path] + covargs + [
                         '-2008',
                         '-work',
                         'lib',
                         'file.vhd'], env=simif.get_env())
            elif file_type == "verilog":
                check_output.assert_called_once_with(
                    [join('prefix', 'vlog'),
                     '-quiet',
                     '-lc',
                     library_cfg] + covargs + [
                         '-work',
                         'lib',
                         'file.v',
                         '-l', 'lib'],
                    env=simif.get_env())
            else:
                assert False

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_rivierapro_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.output_path):
            rmtree(self.output_path)
