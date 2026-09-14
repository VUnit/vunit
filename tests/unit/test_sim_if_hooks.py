# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the simulator hooks
"""

import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from vunit import VUnit
from vunit.project import Project
from vunit.sim_if import hooks
from vunit.sim_if.activehdl import ActiveHDLInterface
from vunit.sim_if.ghdl import GHDLInterface
from vunit.sim_if.modelsim import ModelSimInterface
from vunit.sim_if.nvc import NVCInterface
from vunit.sim_if.rivierapro import RivieraProInterface
from vunit.sim_if.vsim_simulator_mixin import VsimSimulatorMixin
from vunit.vhdl_standard import VHDL
from tests.common import create_tempdir

FLAG_KINDS = ("elab_flags", "run_flags", "process_flags")


def make_config(**kwargs):
    """Create a minimal test configuration."""
    config = SimpleNamespace(
        library_name="lib",
        entity_name="tb",
        architecture_name="arch",
        vhdl_configuration_name=None,
        vhdl_assert_stop_level="error",
        generics={},
        sim_options={},
    )
    for name, value in kwargs.items():
        setattr(config, name, value)

    return config


class TestSimulatorHooks(unittest.TestCase):
    """
    Test the simulator hook registry
    """

    def setUp(self):
        hooks.clear_hooks()

    def tearDown(self):
        hooks.clear_hooks()

    @staticmethod
    def _simulator(name):
        return SimpleNamespace(name=name)

    def test_no_hooks_by_default(self):
        simulator = self._simulator("ghdl")
        for kind in FLAG_KINDS:
            self.assertEqual(hooks.get_flags(simulator, kind), [])
        self.assertIsNone(hooks.get_run_env(simulator))
        self.assertEqual(hooks.get_run_env(simulator, {"FOO": "1"}), {"FOO": "1"})

    def test_calls_hooks_with_the_simulator_interface(self):
        simulator = self._simulator("ghdl")
        hooks.register_hooks(
            "ghdl",
            elab_flags=lambda interface: [f"-Wl,-l{interface.name}"],
            run_flags=lambda interface: ["--load"],
            process_flags=lambda interface: [f"-{interface.name}"],
            run_env=lambda interface, env: dict(env, FOO=interface.name),
        )

        self.assertEqual(hooks.get_flags(simulator, "elab_flags"), ["-Wl,-lghdl"])
        self.assertEqual(hooks.get_flags(simulator, "run_flags"), ["--load"])
        self.assertEqual(hooks.get_flags(simulator, "process_flags"), ["-ghdl"])
        self.assertEqual(hooks.get_run_env(simulator, {"BAR": "1"}), {"BAR": "1", "FOO": "ghdl"})

    def test_combines_hooks_in_registration_order(self):
        simulator = self._simulator("ghdl")
        for kind in FLAG_KINDS:
            hooks.register_hooks("ghdl", **{kind: lambda interface: ["first"]})
            hooks.register_hooks("ghdl", **{kind: lambda interface: ["second"]})

            self.assertEqual(hooks.get_flags(simulator, kind), ["first", "second"])

    def test_hooks_are_specific_to_a_simulator(self):
        for kind in FLAG_KINDS:
            hooks.register_hooks("ghdl", **{kind: lambda interface: ["--load"]})

            self.assertEqual(hooks.get_flags(self._simulator("ghdl"), kind), ["--load"])
            self.assertEqual(hooks.get_flags(self._simulator("nvc"), kind), [])

    def test_copies_the_environment_when_there_is_none(self):
        simulator = self._simulator("ghdl")
        hooks.register_hooks("ghdl", run_env=lambda interface, env: dict(env, FOO="1"))

        env = hooks.get_run_env(simulator)
        self.assertEqual(env["FOO"], "1")
        self.assertIn("PATH", env)

    def test_clears_hooks(self):
        simulator = self._simulator("ghdl")
        hooks.register_hooks("ghdl", elab_flags=lambda interface: ["--load"])
        hooks.clear_hooks()

        self.assertEqual(hooks.get_flags(simulator, "elab_flags"), [])

    def test_raises_if_hook_is_not_callable(self):
        with self.assertRaisesRegex(ValueError, "run_flags hook for simulator ghdl is not callable."):
            hooks.register_hooks("ghdl", run_flags="--load")

        with self.assertRaisesRegex(ValueError, "process_flags hook for simulator ghdl is not callable."):
            hooks.register_hooks("ghdl", process_flags="-noautoldlibpath")

    def test_raises_if_simulator_name_is_invalid(self):
        with self.assertRaisesRegex(ValueError, "Simulator name must be a non-empty string."):
            hooks.register_hooks("", run_flags=lambda interface: [])

    def test_hooks_are_cleared_when_a_vunit_object_is_created(self):
        hooks.register_hooks("ghdl", elab_flags=lambda interface: ["--load"])

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.factory.SIMULATOR_FACTORY.select_simulator", new=lambda: None),
        ):
            VUnit.from_argv(argv=["--output-path=%s" % tempdir])

        self.assertEqual(hooks.get_flags(self._simulator("ghdl"), "elab_flags"), [])


class TestSimulatorHooksAreUsed(unittest.TestCase):
    """
    Test that the simulator interfaces use the registered hooks
    """

    def setUp(self):
        hooks.clear_hooks()

    def tearDown(self):
        hooks.clear_hooks()

    @staticmethod
    def _project():
        project = Project()
        project.add_library("lib", "lib_path")
        return project

    @mock.patch.object(GHDLInterface, "determine_version", return_value=5.0)
    def test_ghdl_uses_hooks(self, determine_version):
        hooks.register_hooks(
            "ghdl",
            elab_flags=lambda interface: ["-Wl,-lfoo"],
            run_flags=lambda interface: ["--load=foo"],
            run_env=lambda interface, env: dict(env, FOO="1"),
        )

        simif = GHDLInterface(prefix="prefix", output_path="")
        simif._project = self._project()  # pylint: disable=protected-access
        simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access

        cmd = simif._get_command(  # pylint: disable=protected-access
            make_config(), "output_path", False, False, "lib.tb", None
        )
        self.assertIn("-Wl,-lfoo", cmd)
        self.assertIn("--load=foo", cmd)
        self.assertLess(cmd.index("-Wl,-lfoo"), cmd.index("--load=foo"))

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.ghdl.Process", autospec=True) as process,
        ):
            simif.simulate(str(tempdir), "lib.tb", make_config(), False)

        self.assertEqual(process.call_args[1]["env"]["FOO"], "1")

    @mock.patch.object(NVCInterface, "determine_version", return_value=(1, 16))
    def test_nvc_uses_hooks(self, determine_version):
        hooks.register_hooks(
            "nvc",
            elab_flags=lambda interface: ["--jit"],
            run_flags=lambda interface: ["--load=foo"],
            run_env=lambda interface, env: dict(env, FOO="1"),
        )

        simif = NVCInterface(prefix="prefix", output_path="", num_threads=1)
        simif._project = self._project()  # pylint: disable=protected-access
        simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.nvc.Process", autospec=True) as process,
        ):
            simif.simulate(str(tempdir), "lib.tb", make_config(), False)

        cmd = process.call_args[0][0]
        self.assertIn("--jit", cmd)
        self.assertIn("--load=foo", cmd)
        self.assertLess(cmd.index("--jit"), cmd.index("-r"))
        self.assertGreater(cmd.index("--load=foo"), cmd.index("-r"))
        self.assertEqual(process.call_args[1]["env"]["FOO"], "1")

    def test_modelsim_uses_hooks(self):
        hooks.register_hooks(
            "modelsim",
            elab_flags=lambda interface: ["-foo"],
            run_flags=lambda interface: ["-bar"],
        )

        simif = SimpleNamespace(name=ModelSimInterface.name, _gui=False)
        self.assertEqual(ModelSimInterface._vopt_extra_args(simif, make_config()), "-foo")
        self.assertEqual(ModelSimInterface._vsim_extra_args(simif, make_config()), "-bar")

    def test_rivierapro_uses_hooks(self):
        hooks.register_hooks("rivierapro", run_flags=lambda interface: ["-bar"])

        simif = SimpleNamespace(name=RivieraProInterface.name, _gui=False)
        self.assertEqual(RivieraProInterface._vsim_extra_args(simif, make_config()), "-bar")

    def test_activehdl_uses_hooks(self):
        hooks.register_hooks("activehdl", run_flags=lambda interface: ["-bar"])

        simif = SimpleNamespace(name=ActiveHDLInterface.name, _gui=False)
        self.assertEqual(ActiveHDLInterface._vsim_extra_args(simif, make_config()), "-bar")


class _VsimSimulator(VsimSimulatorMixin):
    """
    A minimal vsim based simulator interface
    """

    name = "modelsim"

    def __init__(self, sim_cfg_file_name, persistent):
        self._gui = False
        VsimSimulatorMixin.__init__(self, "prefix", persistent, sim_cfg_file_name)

    @staticmethod
    def get_env():
        return {"BASE": "1"}


class TestVsimProcessHooks(unittest.TestCase):
    """
    Test that the vsim based interfaces use the hooks of the vsim process they start
    """

    def setUp(self):
        hooks.clear_hooks()

    def tearDown(self):
        hooks.clear_hooks()

    def test_no_process_hooks_by_default(self):
        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.vsim_simulator_mixin.Process", autospec=True) as process,
        ):
            simif = _VsimSimulator(str(Path(tempdir) / "modelsim.ini"), persistent=True)
            simif._persistent_shell._create_process(1)  # pylint: disable=protected-access
            self.assertNotIn("-noautoldlibpath", process.call_args[0][0])
            self.assertEqual(process.call_args[1]["env"], {"BASE": "1"})

            simif._run_batch_file(str(Path(tempdir) / "batch.do"))  # pylint: disable=protected-access
            self.assertIsNone(process.call_args[1]["env"])

    def test_persistent_vsim_process_uses_hooks(self):
        hooks.register_hooks(
            "modelsim",
            process_flags=lambda interface: ["-noautoldlibpath"],
            run_env=lambda interface, env: dict(env, FOO="1"),
        )

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.vsim_simulator_mixin.Process", autospec=True) as process,
        ):
            simif = _VsimSimulator(str(Path(tempdir) / "modelsim.ini"), persistent=True)
            simif._persistent_shell._create_process(1)  # pylint: disable=protected-access

        args = process.call_args[0][0]
        self.assertEqual(args[-1], "-noautoldlibpath")
        self.assertEqual(process.call_args[1]["env"], {"BASE": "1", "FOO": "1"})

    def test_batch_vsim_process_uses_hooks(self):
        hooks.register_hooks(
            "modelsim",
            process_flags=lambda interface: ["-noautoldlibpath"],
            run_env=lambda interface, env: dict(env, FOO="1"),
        )

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.vsim_simulator_mixin.Process", autospec=True) as process,
        ):
            simif = _VsimSimulator(str(Path(tempdir) / "modelsim.ini"), persistent=False)
            simif._run_batch_file(str(Path(tempdir) / "batch.do"))  # pylint: disable=protected-access

        args = process.call_args[0][0]
        self.assertEqual(args[-1], "-noautoldlibpath")
        self.assertEqual(process.call_args[1]["env"]["FOO"], "1")

    def test_process_flags_are_specific_to_a_simulator(self):
        hooks.register_hooks("rivierapro", process_flags=lambda interface: ["-noautoldlibpath"])

        with (
            create_tempdir() as tempdir,
            mock.patch("vunit.sim_if.vsim_simulator_mixin.Process", autospec=True) as process,
        ):
            simif = _VsimSimulator(str(Path(tempdir) / "modelsim.ini"), persistent=False)
            simif._run_batch_file(str(Path(tempdir) / "batch.do"))  # pylint: disable=protected-access

        self.assertNotIn("-noautoldlibpath", process.call_args[0][0])


if __name__ == "__main__":
    unittest.main()
