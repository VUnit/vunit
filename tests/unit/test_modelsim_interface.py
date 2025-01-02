# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
from vunit.test.bench import Configuration
from vunit.vhdl_standard import VHDL


class TestModelSimInterface(unittest.TestCase):
    """
    Test the ModelSim interface
    """

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    def test_compile_project_vhdl_2008(self, process, check_output):
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008"))
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2002"))
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("93"))
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
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
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
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

        ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "installed")

    def test_copies_modelsim_ini_file_from_user(self):
        (modelsim_ini, installed_modelsim_ini, user_modelsim_ini) = self._get_inis()

        with open(installed_modelsim_ini, "w") as fptr:
            fptr.write("installed")

        with open(user_modelsim_ini, "w") as fptr:
            fptr.write("user")

        with set_env(VUNIT_MODELSIM_INI=user_modelsim_ini):
            ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)

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

        ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
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
            ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)

        with open(modelsim_ini, "r") as fptr:
            self.assertEqual(fptr.read(), "user")

    @mock.patch("vunit.sim_if.modelsim.LOGGER", autospec=True)
    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.modelsim.Process", autospec=True)
    @mock.patch("vunit.sim_if.vsim_simulator_mixin.Process", autospec=True)
    def test_optimize(self, vsim_simulator_mixin_process, modelsim_process, check_output, LOGGER):
        simif = ModelSimInterface(prefix=self.prefix_path, output_path=self.output_path, persistent=False)
        project = Project()
        project.add_library("lib", str(Path(self.libraries_path) / "lib"))
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard("2008"))
        simif.compile_project(project)
        config = make_config(sim_options={"modelsim.three_step_flow": True})

        # First call should optimize design
        simif.simulate(self.simulation_output_path, "test_suite_name", config, False)
        design_to_optimize = "lib.tb(test)"
        expected_calls = [
            mock.call("%s scheduled for optimization.", design_to_optimize),
            mock.call("Acquired library lock for %s to optimize %s.", "lib", design_to_optimize),
            mock.call("Optimizing %s.", design_to_optimize),
            mock.call("%s optimization completed.", design_to_optimize),
        ]
        self.assertEqual(LOGGER.debug.call_count, len(expected_calls))
        LOGGER.debug.assert_has_calls(expected_calls)

        # Second call should reuse the already optimized design
        LOGGER.reset_mock()
        simif.simulate(self.simulation_output_path, "test_suite_name", config, False)
        LOGGER.debug.assert_called_once_with("Reusing optimized %s.", "lib.tb(test)")

        # Fake that design is being optimized and that it is being waited for
        LOGGER.reset_mock()
        simif._optimized_designs[design_to_optimize]["optimized_design"] = None
        simif.simulate(self.simulation_output_path, "test_suite_name", config, False)
        expected_debug_calls = [mock.call("Waiting for %s to be optimized.", design_to_optimize)]
        self.assertEqual(LOGGER.debug.call_count, len(expected_debug_calls))
        LOGGER.debug.assert_has_calls(expected_debug_calls)
        expected_error_calls = [
            mock.call("Failed waiting for %s to be optimized (optimization failed).", design_to_optimize)
        ]
        self.assertEqual(LOGGER.error.call_count, len(expected_error_calls))
        LOGGER.error.assert_has_calls(expected_error_calls)

    def setUp(self):
        self.test_path = str(Path(__file__).parent / "test_modelsim_out")

        self.output_path = str(Path(self.test_path) / "modelsim")
        self.prefix_path = str(Path(self.test_path) / "prefix" / "bin")
        self.libraries_path = str(Path(self.output_path) / "libraries")
        self.simulation_output_path = str(Path(self.test_path) / "test_output" / "lib.tb")
        renew_path(self.test_path)
        renew_path(self.output_path)
        renew_path(self.prefix_path)
        renew_path(self.libraries_path)
        renew_path(self.simulation_output_path)
        installed_modelsim_ini = str(Path(self.prefix_path) / ".." / "modelsim.ini")
        write_file(installed_modelsim_ini, "[Library]")
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.test_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.test_path).exists():
            rmtree(self.test_path)


def make_config(sim_options=None, generics=None, verilog=False):
    """
    Utility to reduce boiler plate in tests
    """
    cfg = mock.Mock(spec=Configuration)
    cfg.library_name = "lib"

    if verilog:
        cfg.entity_name = "tb"
        cfg.architecture_name = None
    else:
        cfg.entity_name = "tb"
        cfg.architecture_name = "test"

    cfg.sim_options = {} if sim_options is None else sim_options
    cfg.generics = {} if generics is None else generics
    cfg.vhdl_configuration_name = None
    cfg.vhdl_assert_stop_level = "error"
    return cfg
