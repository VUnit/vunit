# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test packages providing simulator interfaces
"""

import sys
from pathlib import Path
from unittest import TestCase, mock

from tests.common import create_tempdir
from vunit.sim_if import BooleanOption, SimulatorInterface
from vunit.sim_if.factory import SimulatorFactory
from vunit.ui import VUnit

PACKAGE = """\
from vunit.sim_if import BooleanOption, SimulatorInterface


class FakeSimulator(SimulatorInterface):
    name = "fakesim"
    compile_options = [BooleanOption("fakesim.x")]
    sim_options = [BooleanOption("fakesim.y")]

    @classmethod
    def is_available(cls):
        return True

    @staticmethod
    def add_arguments(parser):
        parser.add_argument("--fakesim-opt", default=None)
"""


class TestSimulatorPackage(TestCase):
    """
    A package declares a simulator with the 'simulator' key of vunit_pkg.toml
    """

    def setUp(self):
        self._tempdir = create_tempdir()
        self._root = Path(self._tempdir.__enter__())
        pkg = self._root / "fakesim_pkg"
        pkg.mkdir()
        (pkg / "__init__.py").write_text(PACKAGE)
        (pkg / "vunit_pkg.toml").write_text('[package]\nsimulator = "fakesim_pkg:FakeSimulator"\n')
        sys.path.insert(0, str(self._root))

        # Registration changes the shared factory
        self._factory = SimulatorFactory()
        for module in ("vunit.builtins", "vunit.ui", "vunit.vunit_cli", "vunit.configuration", "vunit.source_file"):
            patcher = mock.patch(f"{module}.SIMULATOR_FACTORY", self._factory)
            patcher.start()
            self.addCleanup(patcher.stop)

        def cleanup():
            sys.path.remove(str(self._root))
            sys.modules.pop("fakesim_pkg", None)
            self._tempdir.__exit__(None, None, None)

        self.addCleanup(cleanup)

    def _vunit(self, *args):
        return VUnit.from_argv(argv=[f"--output-path={self._root / 'out'}", *args])

    def test_package_simulator_is_selected_with_its_arguments(self):
        with mock.patch.dict("os.environ", {"VUNIT_SIMULATOR": "fakesim"}):
            vu = self._vunit("--fakesim-opt=7")
            vu.add_package("fakesim_pkg", allow_setup=True)
            self.assertEqual(vu.get_simulator_name(), "fakesim")
            self.assertEqual(vu._args.fakesim_opt, "7")  # pylint: disable=protected-access
            self._factory.check_compile_option("fakesim.x", True)

    def test_simulator_package_needs_allow_setup(self):
        vu = self._vunit()
        with self.assertRaises(RuntimeError) as ctx:
            vu.add_package("fakesim_pkg")
        self.assertIn("allow_setup=True", str(ctx.exception))

    def test_simulator_package_after_selection_is_an_error(self):
        vu = self._vunit()
        vu.get_simulator_name()
        with self.assertRaises(RuntimeError) as ctx:
            vu.add_package("fakesim_pkg", allow_setup=True)
        self.assertIn("before any other call", str(ctx.exception))

    def test_unknown_argument_without_package_is_an_error(self):
        vu = self._vunit("--fakesim-opt=7")
        with mock.patch("sys.stderr"), self.assertRaises(SystemExit):
            vu.get_simulator_name()

    def test_invalid_simulator_spec(self):
        (self._root / "fakesim_pkg" / "vunit_pkg.toml").write_text('[package]\nsimulator = "nocolon"\n')
        vu = self._vunit()
        with self.assertRaises(RuntimeError):
            vu.add_package("fakesim_pkg", allow_setup=True)

    def test_bad_option_name_is_rejected_and_rolled_back(self):
        class Bad(SimulatorInterface):
            name = "bad"
            compile_options = [BooleanOption("other.x")]
            sim_options = []

        with self.assertRaises(ValueError):
            self._factory.register_simulator(Bad)
        self.assertNotIn(Bad, self._factory.supported_simulators())

    def test_duplicate_name_is_rejected(self):
        with self.assertRaises(ValueError):
            self._factory.register_simulator(type("Dup", (SimulatorInterface,), {"name": "ghdl"}))
