# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the RivieraPro interface
"""


import unittest
from pathlib import Path
import os
from shutil import rmtree
from unittest import mock
from vunit.sim_if.rivierapro import RivieraProInterface
from vunit.project import Project
from vunit.ostools import renew_path, write_file
from vunit.vhdl_standard import VHDL


class TestRivieraProInterface(unittest.TestCase):
    """
    Test the RivieraPro interface
    """

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_vhdl_2019(self, _find_prefix, process, check_output):
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2019"))
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "-2019",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_vhdl_2008(self, _find_prefix, process, check_output):
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008"))
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "-2008",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_vhdl_2002(self, _find_prefix, process, check_output):
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2002"))
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "-2002",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_vhdl_93(self, _find_prefix, process, check_output):
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("93"))
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "-93",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_vhdl_extra_flags(self, _find_prefix, process, check_output):
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("rivierapro.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "custom",
                "flags",
                "-2008",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_verilog(self, _find_prefix, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_system_verilog(self, _find_prefix, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-sv2k12",
                "-work",
                "lib",
                "file.sv",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_verilog_extra_flags(self, _find_prefix, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("rivierapro.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "custom",
                "flags",
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_verilog_include(self, _find_prefix, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=None,
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
                "+incdir+include",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.rivierapro.Process", autospec=True)
    @mock.patch("vunit.sim_if.rivierapro.RivieraProInterface.find_prefix", return_value="prefix")
    def test_compile_project_verilog_define(self, _find_prefix, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = RivieraProInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
                "+define+defname=defval",
            ],
            env=simif.get_env(),
        )

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_rivierapro_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)
