# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the VHDL-to-Python bridge (vunit/python_bridge)

These tests must never invoke an HDL simulator. Compiling the small C bridge
library with the system C compiler, and reading/writing files, is fine.
"""

import os
import re
import shutil
import subprocess
import sys
import unittest
from glob import glob
from pathlib import Path
from unittest import mock

from vunit.python_bridge import bridge as bridge_setup, foreign_application, native_library, simulator_hooks
from vunit.builtins import Builtins, VHDL_PATH
from vunit.vhdl_standard import VHDLStandard
from vunit.sim_if import SimulatorInterface
from tests.common import create_tempdir


class _FakeSimulator:
    """
    Minimal stand-in for a simulator interface class, as used directly by
    bridge_setup.setup() (name, find_prefix(), determine_backend()).
    """

    def __init__(self, name, backend=None, prefix="prefix"):
        self.name = name
        self._backend = backend
        self._prefix = prefix

    def find_prefix(self):
        return self._prefix

    def determine_backend(self, prefix):  # pylint: disable=unused-argument
        return self._backend


def _autospec_simulator(name):
    """
    A simulator-interface autospec stand-in for use through Builtins, whose
    _add_files()/_add_vhdl_logging() call several other simulator-interface
    methods (supports_vhdl_contexts(), supports_vhdl_call_paths(), ...) that
    are irrelevant to what these tests check, so let them return truthy mocks.
    """
    simulator = mock.create_autospec(SimulatorInterface, instance=True)
    simulator.name = name
    return simulator


class _BridgeKey:
    """
    A plain, weak-referenceable object to use as a project key in bridge_setup._BRIDGES.
    (A bare ``object()`` cannot be weakly referenced.)
    """


# The complete VHPIDIRECT contract between python_bridge_pkg.vhd.in and
# native/*.c. The generated VHDL and the built library must agree on it
# exactly: nothing else may be exported.
EXPECTED_EXPORTS = (
    "vpy_setup",
    "vpy_cleanup",
    "vpy_buffer_clear",
    "vpy_buffer_append",
    "vpy_begin",
    "vpy_execute",
    "vpy_eval",
    "vpy_push_array",
    "vpy_array_write",
    "vpy_stage",
    "vpy_result_integer",
    "vpy_result_real",
    "vpy_result_meta",
    "vpy_result_read_string",
    "vpy_result_read_integers",
    "vpy_result_read_reals",
    "vpy_error_length",
    "vpy_error_read",
)


def _write_run_script(path: Path) -> Path:
    """
    A stub run script; its directory is put on sys.path by the runtime.
    """
    path.write_text("# run script stub\n", encoding="utf-8")
    return path


class TestAddPython(unittest.TestCase):
    """
    add_python() wiring: Builtins._add_python()/_add_python_bridge() behind the
    ``vu.add_vhdl_builtins(); vu.add_python()`` API. add_vhdl_builtins() is
    unconditional (no ``python`` parameter, always adds the unmodified
    vunit_context.vhd) and add_python() adds python_context.vhd + python_pkg.vhd
    plus, depending on simulator_class.supported_foreign_language_interfaces():
    python_pkg_vhpi.vhd (VHPI) or the Python bridge's generated files (FLI and
    VHPIDIRECT_*), with bridge_setup.setup() stubbed so no compilation happens
    here.
    """

    def setUp(self):
        self.vu = mock.Mock()
        self.vu._project = mock.Mock()
        self.vu._project._libraries = []
        self.vu._output_path = "/fake/output/path"
        self.vu._run_script_path = Path("/fake/run_script/run.py")
        self.library_mock = mock.Mock()

        def add_library(name):
            self.vu._project._libraries.append(name)
            return self.library_mock

        self.vu.add_library.side_effect = add_library

    def _builtins(self, vhdl_standard="2008", simulator=None):
        return Builtins(self.vu, VHDLStandard(vhdl_standard), simulator)

    def _added_files(self):
        return [Path(call.args[0]) for call in self.library_mock.add_source_file.call_args_list]

    @staticmethod
    def _simulator_with_flis(name, flis):
        simulator = _autospec_simulator(name)
        simulator.supported_foreign_language_interfaces.return_value = flis
        return simulator

    def test_add_vhdl_builtins_never_touches_the_bridge(self):
        builtins = self._builtins(simulator=_autospec_simulator("nvc"))
        with mock.patch("vunit.python_bridge.bridge.setup") as setup_mock:
            builtins.add_vhdl_builtins()
        setup_mock.assert_not_called()

        added_files = self._added_files()
        added_names = {p.name for p in added_files}
        self.assertIn("vunit_context.vhd", added_names)
        self.assertNotIn("python_pkg.vhd", added_names)
        self.assertNotIn("python_context.vhd", added_names)
        self.assertIn(VHDL_PATH / "vunit_context.vhd", added_files)

    def test_add_python_before_add_vhdl_builtins_raises(self):
        builtins = self._builtins(simulator=_autospec_simulator("nvc"))
        with self.assertRaisesRegex(RuntimeError, "add_python\\(\\) requires add_vhdl_builtins\\(\\)"):
            builtins.add("python")

    def test_rejects_pre_2008_vhdl(self):
        builtins = self._builtins(vhdl_standard="2002", simulator=_autospec_simulator("nvc"))
        builtins.add_vhdl_builtins()
        with self.assertRaisesRegex(RuntimeError, "vhdl 2008 and later"):
            builtins.add("python")

    def test_rejects_simulator_class_none(self):
        builtins = self._builtins(simulator=None)
        builtins._vhdl_builtins_added = True  # pylint: disable=protected-access
        with self.assertRaisesRegex(RuntimeError, "no simulator was found"):
            builtins.add("python")

    def test_rejects_unsupported_simulator(self):
        simulator = self._simulator_with_flis("some_simulator", {"SOME_OTHER_INTERFACE"})
        builtins = self._builtins(simulator=simulator)
        builtins.add_vhdl_builtins()
        with self.assertRaisesRegex(RuntimeError, "supports none of them") as ctx:
            builtins.add("python")
        # The message names the interfaces so a user knows what is supported.
        self.assertIn("VHPI", str(ctx.exception))
        self.assertIn("FLI", str(ctx.exception))
        self.assertIn("VHPIDIRECT_NVC", str(ctx.exception))
        self.assertIn("VHPIDIRECT_GHDL", str(ctx.exception))

    def test_vhpi_adds_python_pkg_vhpi_and_builds_the_application(self):
        simulator = self._simulator_with_flis("rivierapro", {"VHPI"})
        builtins = self._builtins(simulator=simulator)
        builtins.add_vhdl_builtins()
        with mock.patch("vunit.python_bridge.bridge.setup") as setup_mock, mock.patch(
            "vunit.builtins.setup_vhpi_application"
        ) as vhpi_mock:
            builtins.add("python")
        setup_mock.assert_not_called()
        vhpi_mock.assert_called_once_with(builtins._vunit_obj._output_path, simulator)  # pylint: disable=protected-access

        src_path = VHDL_PATH / "python" / "src"
        added_files = self._added_files()
        self.assertIn(src_path / "python_context.vhd", added_files)
        self.assertIn(src_path / "python_pkg.vhd", added_files)
        self.assertIn(src_path / "python_pkg_vhpi.vhd", added_files)

    def test_application_build_failure_is_reported(self):
        simulator = self._simulator_with_flis("rivierapro", {"VHPI"})
        builtins = self._builtins(simulator=simulator)
        builtins.add_vhdl_builtins()
        with mock.patch("vunit.builtins.setup_vhpi_application", side_effect=RuntimeError("no compiler")), mock.patch(
            "vunit.builtins.LOGGER"
        ) as logger:
            with self.assertRaises(SystemExit):
                builtins.add("python")
        logger.error.assert_called_once_with("%s", mock.ANY)

    def _check_bridge_files_added(self, simulator):
        """
        add_python() adds the generated bridge files, and not the VHPI
        application package, for a simulator served by the Python bridge.
        """
        builtins = self._builtins(simulator=simulator)
        builtins.add_vhdl_builtins()

        fake_bridge = bridge_setup.PythonBridge(
            library_file=Path("/fake/cache/libvunit_python_bridge.so"),
            vhdl_files=[
                Path("/fake/out/python_bridge/vhdl/python_bridge_pkg.vhd"),
                bridge_setup.VHDL_SOURCE_PATH / "python_ffi_pkg_bridge.vhd",
            ],
        )
        with mock.patch("vunit.python_bridge.bridge.setup", return_value=fake_bridge) as setup_mock:
            builtins.add("python")

        # The bridge must be handed the VUnit object's own project, output
        # path, simulator class and run script path (whose directory the
        # runtime puts on sys.path, like python does for a run script).
        setup_mock.assert_called_once_with(
            self.vu._project, self.vu._output_path, simulator, self.vu._run_script_path
        )

        src_path = VHDL_PATH / "python" / "src"
        added_files = self._added_files()
        self.assertIn(src_path / "python_context.vhd", added_files)
        self.assertIn(src_path / "python_pkg.vhd", added_files)
        for expected in fake_bridge.vhdl_files:
            self.assertIn(expected, added_files)
        self.assertNotIn(src_path / "python_pkg_vhpi.vhd", added_files)

    def test_vhpidirect_adds_the_bridge_files(self):
        self._check_bridge_files_added(self._simulator_with_flis("nvc", {"VHPIDIRECT_NVC"}))

    def test_fli_adds_the_bridge_files(self):
        # Questa/ModelSim is served by the bridge too, through native/fli.c.
        self._check_bridge_files_added(self._simulator_with_flis("modelsim", {"FLI"}))

    def test_fli_uses_the_bridge_not_the_vhpi_application(self):
        simulator = self._simulator_with_flis("modelsim", {"FLI"})
        builtins = self._builtins(simulator=simulator)
        builtins.add_vhdl_builtins()
        with mock.patch("vunit.python_bridge.bridge.setup"), mock.patch(
            "vunit.builtins.setup_vhpi_application"
        ) as vhpi_mock:
            builtins.add("python")
        vhpi_mock.assert_not_called()

    def test_importing_python_bridge_has_no_side_effects(self):
        # Re-importing must not create any files or directories or run any subprocess.
        def listing():
            return sorted(
                str(path) for path in native_library.PACKAGE_PATH.rglob("*") if "__pycache__" not in str(path)
            )

        before = listing()
        with mock.patch("subprocess.run") as run_mock:
            import importlib

            for module in (native_library, bridge_setup, simulator_hooks):
                importlib.reload(module)
        run_mock.assert_not_called()
        self.assertEqual(listing(), before)


class TestFindRunScriptPath(unittest.TestCase):
    """
    vunit.ui._find_run_script_path(): the file of the first call-stack frame
    outside the vunit package, used as the VUnit object's ``_run_script_path``
    (fed to the Python bridge and, through run_script_path(runner_cfg), to
    import_run_script).
    """

    def test_returns_the_file_of_the_caller_outside_vunit(self):
        from vunit.ui import _find_run_script_path  # pylint: disable=import-outside-toplevel

        self.assertEqual(_find_run_script_path(), Path(__file__).resolve())


class TestBridgePackageSubstitution(unittest.TestCase):
    """
    Library token substitution into the generated python_bridge_pkg.vhd.
    """

    def setUp(self):
        self.tempdir_cm = create_tempdir()
        self.tempdir = self.tempdir_cm.__enter__()
        self.addCleanup(self.tempdir_cm.__exit__, None, None, None)
        self.run_script = _write_run_script(self.tempdir / "run.py")

    def _setup(self, simulator, library_file_name="libvunit_python_bridge.so"):
        fake_library_file = self.tempdir / "cache" / library_file_name
        with mock.patch("vunit.python_bridge.bridge.prepare_library", return_value=fake_library_file):
            return bridge_setup.setup(_BridgeKey(), self.tempdir / "out", simulator, self.run_script)

    def _fli_setup(self):
        return self._setup(_FakeSimulator("modelsim"), library_file_name="libvunit_python_bridge_fli.so")

    def _ffi_text(self, bridge):
        for path in bridge.vhdl_files:
            if path.name == "python_bridge_pkg.vhd":
                return path.read_text(encoding="utf-8")
        self.fail("python_bridge_pkg.vhd not found among bridge.vhdl_files")
        return ""

    def test_generated_package_is_the_private_bridge_package(self):
        text = self._ffi_text(self._setup(_FakeSimulator("nvc")))
        self.assertIn("package python_bridge_pkg is", text)
        self.assertIn("package body python_bridge_pkg is", text)

    def test_exports_match_the_native_library(self):
        text = self._ffi_text(self._setup(_FakeSimulator("nvc")))
        declared = set(re.findall(r'VHPIDIRECT \S+ (\w+)"', text))
        self.assertEqual(declared, set(EXPECTED_EXPORTS))

    def test_token_is_library_file_name_for_nvc(self):
        bridge = self._setup(_FakeSimulator("nvc"))
        text = self._ffi_text(bridge)
        self.assertIn('"VHPIDIRECT libvunit_python_bridge.so vpy_begin"', text)

    def test_token_is_library_file_name_for_ghdl_mcode(self):
        bridge = self._setup(_FakeSimulator("ghdl", backend="mcode"))
        text = self._ffi_text(bridge)
        self.assertIn('"VHPIDIRECT libvunit_python_bridge.so vpy_begin"', text)

    def test_token_is_library_file_name_for_ghdl_llvm_jit(self):
        bridge = self._setup(_FakeSimulator("ghdl", backend="llvm-jit"))
        text = self._ffi_text(bridge)
        self.assertIn('"VHPIDIRECT libvunit_python_bridge.so vpy_begin"', text)

    def test_token_is_link_flag_for_ghdl_llvm(self):
        bridge = self._setup(_FakeSimulator("ghdl", backend="llvm"))
        text = self._ffi_text(bridge)
        self.assertIn('"VHPIDIRECT -lvunit_python_bridge vpy_begin"', text)

    def test_token_is_link_flag_for_ghdl_gcc(self):
        bridge = self._setup(_FakeSimulator("ghdl", backend="gcc"))
        text = self._ffi_text(bridge)
        self.assertIn('"VHPIDIRECT -lvunit_python_bridge vpy_begin"', text)

    def test_no_remaining_placeholder(self):
        for bridge in (self._setup(_FakeSimulator("nvc")), self._fli_setup()):
            text = self._ffi_text(bridge)
            self.assertNotIn("{library}", text)
            self.assertNotIn("{foreign:vpy_", text)

    def test_fli_attributes_name_the_wrapper_and_the_library_path(self):
        # Questa resolves the absolute path, so the library stays in the cache.
        bridge = self._fli_setup()
        text = self._ffi_text(bridge)
        self.assertIn(f'"fli_vpy_begin {bridge.library_file!s}"', text)
        self.assertIn(f'"fli_vpy_result_read_reals {bridge.library_file!s}"', text)
        attributes = [line for line in text.splitlines() if "attribute foreign" in line]
        self.assertEqual([line for line in attributes if "VHPIDIRECT" in line or "{foreign:" in line], [])

    def test_fli_attributes_cover_every_entry_point(self):
        bridge = self._fli_setup()
        text = self._ffi_text(bridge)
        declared = set(re.findall(r'"fli_(\w+) \S+"', text))
        self.assertEqual(declared, set(EXPECTED_EXPORTS))

    def test_fli_library_is_the_fli_variant(self):
        with mock.patch("vunit.python_bridge.bridge.prepare_library") as prepare_mock:
            prepare_mock.return_value = self.tempdir / "cache" / "libvunit_python_bridge_fli.so"
            bridge_setup.setup(
                _BridgeKey(), self.tempdir / "out", _FakeSimulator("modelsim", prefix="/sim/bin"), self.run_script
            )
        # The simulator prefix selects the FLI variant of the library.
        self.assertEqual(prepare_mock.call_args.args[1], Path("/sim/bin"))

    def test_no_simulator_prefix_for_vhpidirect(self):
        with mock.patch("vunit.python_bridge.bridge.prepare_library") as prepare_mock:
            prepare_mock.return_value = self.tempdir / "cache" / "libvunit_python_bridge.so"
            bridge_setup.setup(_BridgeKey(), self.tempdir / "out", _FakeSimulator("nvc"), self.run_script)
        self.assertIsNone(prepare_mock.call_args.args[1])

    def test_unsupported_simulator_raises(self):
        with self.assertRaisesRegex(RuntimeError, "NVC, GHDL or Questa/ModelSim"):
            self._setup(_FakeSimulator("rivierapro"))

    def test_all_vhpidirect_tokens_fit_ghdl_limit(self):
        for simulator in (
            _FakeSimulator("nvc"),
            _FakeSimulator("ghdl", backend="mcode"),
            _FakeSimulator("ghdl", backend="llvm"),
            _FakeSimulator("ghdl", backend="gcc"),
        ):
            bridge = self._setup(simulator)
            text = self._ffi_text(bridge)
            tokens = re.findall(r'VHPIDIRECT\s+(\S+)\s+\S+"', text)
            self.assertTrue(tokens, "no VHPIDIRECT tokens found")
            for token in tokens:
                self.assertLessEqual(len(token), 32, f"token {token!r} exceeds GHDL's 32 character limit")
                self.assertNotIn(" ", token)


@unittest.skipIf(sys.platform == "win32", "POSIX build/cache behavior")
class TestPosixBuildAndCache(unittest.TestCase):
    """
    Compilation and caching of the native bridge library on Linux/macOS.

    Only a couple of real compiles happen here (gcc + Python headers are
    available in this environment); everything else is asserted not to compile.
    """

    def setUp(self):
        self.tempdir_cm = create_tempdir()
        self.tempdir = self.tempdir_cm.__enter__()
        self.addCleanup(self.tempdir_cm.__exit__, None, None, None)
        self.run_script = _write_run_script(self.tempdir / "run.py")

    def _setup(self, output_path=None):
        return bridge_setup.setup(_BridgeKey(), output_path or self.tempdir / "out", None, self.run_script)

    def test_first_setup_compiles_and_names_library(self):
        bridge = self._setup()
        self.assertTrue(bridge.library_file.is_file())
        self.assertEqual(bridge.library_file.name, "libvunit_python_bridge.so")

    def test_second_setup_reuses_cache_without_compiling(self):
        self._setup()
        with mock.patch("subprocess.run") as run_mock:
            bridge = self._setup()
        run_mock.assert_not_called()
        self.assertTrue(bridge.library_file.is_file())

    def test_changed_source_gets_new_cache_dir_and_recompiles(self):
        first = self._setup()

        modified_native = self.tempdir / "native"
        shutil.copytree(native_library.NATIVE_PATH, modified_native)
        with (modified_native / "error.c").open("a", encoding="utf-8") as fptr:
            fptr.write("\n/* test tweak */\n")

        with mock.patch("vunit.python_bridge.native_library.NATIVE_PATH", modified_native):
            second = self._setup()

        self.assertNotEqual(first.library_file.parent, second.library_file.parent)
        self.assertTrue(second.library_file.is_file())

    def test_compile_failure_raises_with_compiler_output(self):
        fake_proc = mock.Mock(returncode=1, stdout=b"bogus.c:1:1: error: fake failure\n")
        with mock.patch("subprocess.run", return_value=fake_proc):
            with self.assertRaisesRegex(RuntimeError, "fake failure"):
                self._setup()

    def test_missing_python_h_raises_actionable_error(self):
        empty_include_dir = self.tempdir / "no_headers"
        empty_include_dir.mkdir()
        real_get_paths = native_library.sysconfig.get_paths

        def fake_get_paths():
            paths = dict(real_get_paths())
            paths["include"] = str(empty_include_dir)
            paths["platinclude"] = str(empty_include_dir)
            return paths

        with mock.patch("vunit.python_bridge.native_library.sysconfig.get_paths", side_effect=fake_get_paths):
            with self.assertRaisesRegex(RuntimeError, "Python.h"):
                self._setup()

    def test_static_only_python_raises(self):
        real_get_config_var = native_library.sysconfig.get_config_var

        def fake_get_config_var(name):
            if name == "Py_ENABLE_SHARED":
                return 0
            return real_get_config_var(name)

        with mock.patch("vunit.python_bridge.native_library.sysconfig.get_config_var", side_effect=fake_get_config_var):
            with self.assertRaisesRegex(RuntimeError, "shared Python library"):
                self._setup()

    def test_free_threaded_python_raises(self):
        real_get_config_var = native_library.sysconfig.get_config_var

        def fake_get_config_var(name):
            if name == "Py_GIL_DISABLED":
                return 1
            return real_get_config_var(name)

        with mock.patch("vunit.python_bridge.native_library.sysconfig.get_config_var", side_effect=fake_get_config_var):
            with self.assertRaisesRegex(RuntimeError, "free-threaded"):
                self._setup()

    def test_library_exports_exactly_the_contract(self):
        nm = shutil.which("nm")
        if nm is None:
            self.skipTest("nm is not available")
        bridge = self._setup()
        proc = subprocess.run(
            [nm, "-D", "--defined-only", str(bridge.library_file)],
            check=True,
            capture_output=True,
            text=True,
        )
        exported = set()
        for line in proc.stdout.splitlines():
            fields = line.split()
            if len(fields) >= 3 and fields[-2] in "TtWwDdBb":
                exported.add(fields[-1])
        # -fvisibility=hidden plus VPY_EXPORT: only the contract is exported,
        # no bridge internals (vpy_initialize, vpy_set_error, ...) leak out.
        self.assertEqual(exported, set(EXPECTED_EXPORTS))

    def _fake_simulator_prefix(self):
        """
        A simulator installation with just the FLI header the build needs.
        """
        include = self.tempdir / "questa" / "include"
        include.mkdir(parents=True)
        (include / "mti.h").write_text("/* fake */\n", encoding="utf-8")
        prefix = self.tempdir / "questa" / "bin"
        prefix.mkdir()
        return prefix

    @staticmethod
    def _compiler_stub(calls):
        """
        Stand in for the C compiler: record the command and create its output.
        """

        def run(cmd, **kwargs):  # pylint: disable=unused-argument
            calls.append(cmd)
            Path(cmd[cmd.index("-o") + 1]).write_bytes(b"")
            return mock.Mock(returncode=0, stdout=b"")

        return run

    def test_fli_variant_adds_the_front_end_and_the_simulator_headers(self):
        prefix = self._fake_simulator_prefix()
        calls = []
        with mock.patch("subprocess.run", side_effect=self._compiler_stub(calls)):
            library_file = native_library.prepare_library(self.tempdir / "out", prefix)
        self.assertEqual(len(calls), 1)
        self.assertEqual(library_file.name, "libvunit_python_bridge_fli.so")
        self.assertIn(str(native_library.NATIVE_PATH / "fli.c"), calls[0])
        self.assertIn(f"-I{prefix.parent / 'include'!s}", calls[0])

    def test_vhpidirect_variant_omits_the_front_end(self):
        calls = []
        with mock.patch("subprocess.run", side_effect=self._compiler_stub(calls)):
            library_file = native_library.prepare_library(self.tempdir / "out")
        self.assertEqual(library_file.name, "libvunit_python_bridge.so")
        self.assertNotIn(str(native_library.NATIVE_PATH / "fli.c"), calls[0])

    def test_fli_and_vhpidirect_variants_are_cached_separately(self):
        prefix = self._fake_simulator_prefix()
        calls = []
        with mock.patch("subprocess.run", side_effect=self._compiler_stub(calls)):
            vhpidirect = native_library.prepare_library(self.tempdir / "out")
            fli = native_library.prepare_library(self.tempdir / "out", prefix)
        self.assertEqual(len(calls), 2)
        self.assertNotEqual(fli.parent, vhpidirect.parent)

    def test_second_fli_setup_reuses_cache_without_compiling(self):
        prefix = self._fake_simulator_prefix()
        with mock.patch("subprocess.run", side_effect=self._compiler_stub([])):
            first = native_library.prepare_library(self.tempdir / "out", prefix)
        with mock.patch("subprocess.run") as run_mock:
            second = native_library.prepare_library(self.tempdir / "out", prefix)
        run_mock.assert_not_called()
        self.assertEqual(first, second)

    def test_another_simulator_installation_gets_its_own_cache_dir(self):
        first_prefix = self._fake_simulator_prefix()
        other = self.tempdir / "other_questa"
        (other / "include").mkdir(parents=True)
        (other / "include" / "mti.h").write_text("/* fake */\n", encoding="utf-8")
        (other / "bin").mkdir()
        calls = []
        with mock.patch("subprocess.run", side_effect=self._compiler_stub(calls)):
            first = native_library.prepare_library(self.tempdir / "out", first_prefix)
            second = native_library.prepare_library(self.tempdir / "out", other / "bin")
        self.assertEqual(len(calls), 2)
        self.assertNotEqual(first.parent, second.parent)

    def test_missing_mti_h_raises_actionable_error(self):
        prefix = self.tempdir / "questa" / "bin"
        prefix.mkdir(parents=True)
        with self.assertRaisesRegex(RuntimeError, "mti.h"):
            native_library.prepare_library(self.tempdir / "out", prefix)

    def test_no_prebuilt_library_in_repository(self):
        # Linux libraries are built on first use and Windows DLLs are added to releases by CI
        matches = []
        for pattern in ["*.so", "*.dll"]:
            matches += glob(str(native_library.PACKAGE_PATH / "**" / pattern), recursive=True)
            matches += glob(str(VHDL_PATH / "**" / pattern), recursive=True)
        self.assertEqual(matches, [])


class TestConfigFile(unittest.TestCase):
    """
    _config_text / _write_if_changed
    """

    def test_config_keys_linux(self):
        with mock.patch("sys.platform", "linux"):
            text = bridge_setup._config_text("/run/script/dir")  # pylint: disable=protected-access
        keys = dict(line.split("=", 1) for line in text.splitlines())
        self.assertEqual(set(keys), {"executable", "prefix", "runtime", "run_script_dir"})
        self.assertEqual(keys["executable"], sys.executable)
        self.assertEqual(keys["prefix"], sys.prefix)
        self.assertEqual(keys["runtime"], str(bridge_setup.RUNTIME_SOURCE))
        self.assertEqual(keys["run_script_dir"], "/run/script/dir")

    def test_config_keys_windows_include_python_dll(self):
        with (
            mock.patch("sys.platform", "win32"),
            mock.patch("vunit.python_bridge.bridge.windows_python_dll", return_value=r"C:\python.dll"),
        ):
            text = bridge_setup._config_text("/run/script/dir")  # pylint: disable=protected-access
        keys = dict(line.split("=", 1) for line in text.splitlines())
        self.assertEqual(keys["python_dll"], r"C:\python.dll")

    def test_write_if_changed_does_not_rewrite_identical_content(self):
        with create_tempdir() as tempdir:
            path = tempdir / "file.txt"
            bridge_setup._write_if_changed(path, "hello")  # pylint: disable=protected-access
            mtime_before = path.stat().st_mtime_ns
            bridge_setup._write_if_changed(path, "hello")  # pylint: disable=protected-access
            self.assertEqual(path.stat().st_mtime_ns, mtime_before)

    def test_write_if_changed_rewrites_changed_content(self):
        with create_tempdir() as tempdir:
            path = tempdir / "file.txt"
            bridge_setup._write_if_changed(path, "hello")  # pylint: disable=protected-access
            bridge_setup._write_if_changed(path, "world")  # pylint: disable=protected-access
            self.assertEqual(path.read_text(encoding="utf-8"), "world")

    def test_run_script_dir_is_the_directory_of_the_run_script(self):
        with create_tempdir() as tempdir:
            run_script = _write_run_script(tempdir / "run.py")
            fake_library_file = tempdir / "cache" / "libvunit_python_bridge.so"
            with mock.patch("vunit.python_bridge.bridge.prepare_library", return_value=fake_library_file):
                bridge_setup.setup(_BridgeKey(), tempdir / "out", None, run_script)
            config = (fake_library_file.parent / bridge_setup.CONFIG_FILE_NAME).read_text(encoding="utf-8")
            keys = dict(line.split("=", 1) for line in config.splitlines())
            self.assertEqual(keys["run_script_dir"], str(tempdir.resolve()))

    def test_config_paths_with_spaces_and_unicode_written_as_utf8(self):
        with create_tempdir() as tempdir:
            weird_dir = tempdir / "weird dir \u00e5\u00e4\u00f6 \u65e5\u672c\u8a9e"
            weird_dir.mkdir()
            with mock.patch("sys.platform", "linux"):
                text = bridge_setup._config_text(str(weird_dir))  # pylint: disable=protected-access
            self.assertIn(str(weird_dir), text)
            path = tempdir / "cfg"
            bridge_setup._write_if_changed(path, text)  # pylint: disable=protected-access
            self.assertEqual(path.read_text(encoding="utf-8"), text)

    def test_line_break_in_path_raises(self):
        with mock.patch("sys.executable", "/usr/bin/py\nthon"):
            with self.assertRaisesRegex(RuntimeError, "line breaks"):
                bridge_setup._config_text("/run/script/dir")  # pylint: disable=protected-access


class TestWindowsDllSelection(unittest.TestCase):
    """
    Windows prebuilt-DLL selection logic. Testable on any platform since it
    is pure logic + file copying, gated only by explicit patches here (never
    by sys.platform inside these helper functions themselves).
    """

    def test_windows_dll_name_for_supported_versions(self):
        for minor in range(10, 15):
            self.assertEqual(
                native_library.windows_dll_name((3, minor)),
                f"vunit_python_bridge-cp3{minor}-win_amd64.dll",
            )

    def _prepare(self, tempdir, dll_bytes, version_info=(3, 12)):
        binary_path = tempdir / "bin"
        binary_path.mkdir(exist_ok=True)
        name = native_library.windows_dll_name(version_info)
        (binary_path / name).write_bytes(dll_bytes)
        root = tempdir / "root"
        with (
            mock.patch("vunit.python_bridge.native_library.BINARY_PATH", binary_path),
            mock.patch("sys.version_info", version_info),
            mock.patch("vunit.python_bridge.native_library.sysconfig.get_platform", return_value="win-amd64"),
            mock.patch("subprocess.run") as run_mock,
            mock.patch("shutil.which") as which_mock,
        ):
            target = native_library._prepare_windows_library(root)  # pylint: disable=protected-access
        run_mock.assert_not_called()
        which_mock.assert_not_called()
        return target

    def test_copies_selected_dll_as_vunit_python_bridge_dll(self):
        with create_tempdir() as tempdir:
            target = self._prepare(tempdir, b"fake-dll-content")
            self.assertEqual(target.name, "vunit_python_bridge.dll")
            self.assertEqual(target.read_bytes(), b"fake-dll-content")

    def test_reuses_existing_file_when_content_unchanged(self):
        with create_tempdir() as tempdir:
            first = self._prepare(tempdir, b"same-content")
            mtime_before = first.stat().st_mtime_ns
            second = self._prepare(tempdir, b"same-content")
            self.assertEqual(first, second)
            self.assertEqual(second.stat().st_mtime_ns, mtime_before)

    def test_new_directory_when_content_changes(self):
        with create_tempdir() as tempdir:
            first = self._prepare(tempdir, b"version-one")
            second = self._prepare(tempdir, b"version-two")
            self.assertNotEqual(first.parent, second.parent)

    def test_missing_dll_for_running_version_raises_actionable_error(self):
        root = None
        with create_tempdir() as tempdir:
            binary_path = tempdir / "bin"
            binary_path.mkdir()
            root = tempdir / "root"
            with (
                mock.patch("vunit.python_bridge.native_library.BINARY_PATH", binary_path),
                mock.patch("sys.version_info", (3, 12)),
                mock.patch("vunit.python_bridge.native_library.sysconfig.get_platform", return_value="win-amd64"),
                mock.patch("subprocess.run") as run_mock,
            ):
                with self.assertRaisesRegex(RuntimeError, "No prebuilt Python bridge DLL"):
                    native_library._prepare_windows_library(root)  # pylint: disable=protected-access
            run_mock.assert_not_called()

    def test_non_win_amd64_platform_raises(self):
        with mock.patch("vunit.python_bridge.native_library.sysconfig.get_platform", return_value="mingw"):
            with self.assertRaisesRegex(RuntimeError, "64-bit"):
                native_library._prepare_windows_library(Path("root"))  # pylint: disable=protected-access


class TestSimulatorHooks(unittest.TestCase):
    """
    nvc_run_flags / ghdl_elab_flags / ghdl_run_env / modelsim_vsim_flags
    """

    def setUp(self):
        self.project = _BridgeKey()
        self.addCleanup(bridge_setup._BRIDGES.pop, self.project, None)  # pylint: disable=protected-access

    def _register(self, library_file):
        bridge = bridge_setup.PythonBridge(library_file=library_file, vhdl_files=[])
        bridge_setup._BRIDGES[self.project] = bridge  # pylint: disable=protected-access
        return bridge

    def test_nvc_run_flags_empty_without_bridge(self):
        self.assertEqual(simulator_hooks.nvc_run_flags(self.project), [])

    def test_nvc_run_flags_with_bridge(self):
        bridge = self._register(Path("/some/dir/libvunit_python_bridge.so"))
        self.assertEqual(simulator_hooks.nvc_run_flags(self.project), [f"--load={bridge.library_file!s}"])

    def test_ghdl_elab_flags_empty_without_bridge(self):
        self.assertEqual(simulator_hooks.ghdl_elab_flags(self.project, "llvm"), [])

    def test_ghdl_elab_flags_empty_for_mcode_and_jit(self):
        bridge_dir = Path("/some/dir")
        self._register(bridge_dir / "libvunit_python_bridge.so")
        self.assertEqual(simulator_hooks.ghdl_elab_flags(self.project, "mcode"), [])
        self.assertEqual(simulator_hooks.ghdl_elab_flags(self.project, "llvm-jit"), [])

    def test_ghdl_elab_flags_for_linking_backends(self):
        bridge_dir = Path("/some/dir")
        self._register(bridge_dir / "libvunit_python_bridge.so")
        for backend in ("llvm", "gcc"):
            self.assertEqual(
                simulator_hooks.ghdl_elab_flags(self.project, backend),
                [f"-Wl,-L{bridge_dir!s}"],
            )

    def test_ghdl_run_env_unchanged_without_bridge(self):
        env = {"FOO": "bar"}
        result = simulator_hooks.ghdl_run_env(self.project, env)
        self.assertEqual(result, env)
        self.assertIs(result, env)

    def test_ghdl_run_env_prepends_ld_library_path_without_mutating_input(self):
        bridge_dir = Path("/some/dir")
        self._register(bridge_dir / "libvunit_python_bridge.so")
        env = {"LD_LIBRARY_PATH": "/existing/path"}
        with mock.patch("vunit.python_bridge.native_library.sys.platform", "linux"):
            result = simulator_hooks.ghdl_run_env(self.project, env)
        self.assertEqual(
            result["LD_LIBRARY_PATH"],
            str(bridge_dir) + os.pathsep + "/existing/path",
        )
        # Input must not be mutated.
        self.assertEqual(env, {"LD_LIBRARY_PATH": "/existing/path"})
        self.assertIsNot(result, env)

    def test_ghdl_run_env_uses_dyld_library_path_on_macos(self):
        bridge_dir = Path("/some/dir")
        self._register(bridge_dir / "libvunit_python_bridge.so")
        with mock.patch("vunit.python_bridge.simulator_hooks.sys.platform", "darwin"):
            result = simulator_hooks.ghdl_run_env(self.project, {})
        self.assertEqual(result["DYLD_LIBRARY_PATH"], str(bridge_dir))

    def test_ghdl_run_env_uses_path_variable_on_windows(self):
        bridge_dir = Path("/some/dir")
        self._register(bridge_dir / "libvunit_python_bridge.so")
        with mock.patch("vunit.python_bridge.native_library.sys.platform", "win32"):
            result = simulator_hooks.ghdl_run_env(self.project, {})
        self.assertEqual(result["PATH"], str(bridge_dir))
        self.assertNotIn("LD_LIBRARY_PATH", result)

    def test_modelsim_vsim_flags_empty_without_bridge(self):
        with mock.patch("vunit.python_bridge.simulator_hooks.sys.platform", "linux"):
            self.assertEqual(simulator_hooks.modelsim_vsim_flags(self.project), [])

    def test_modelsim_vsim_flags_disable_the_bundled_cxx_runtime_on_linux(self):
        self._register(Path("/some/dir/libvunit_python_bridge_fli.so"))
        with mock.patch("vunit.python_bridge.simulator_hooks.sys.platform", "linux"):
            self.assertEqual(simulator_hooks.modelsim_vsim_flags(self.project), ["-noautoldlibpath"])

    def test_modelsim_vsim_flags_empty_on_windows(self):
        self._register(Path("/some/dir/vunit_python_bridge_fli.dll"))
        with mock.patch("vunit.python_bridge.simulator_hooks.sys.platform", "win32"):
            self.assertEqual(simulator_hooks.modelsim_vsim_flags(self.project), [])


class TestSimulatorIntegration(unittest.TestCase):
    """
    Confirm the hooks are wired into the real NVC/GHDL command builders at the
    right place.

    Entity() writes a stub source file relative to the cwd, so run these from
    a scratch directory (matching the convention in test_ghdl_interface.py).
    """

    def setUp(self):
        self.tempdir_cm = create_tempdir()
        self.scratch_dir = self.tempdir_cm.__enter__()
        self.addCleanup(self.tempdir_cm.__exit__, None, None, None)
        self.cwd = os.getcwd()
        os.chdir(self.scratch_dir)
        self.addCleanup(os.chdir, self.cwd)

    def test_ghdl_get_command_only_adds_wl_L_for_linking_backends(self):
        from tests.unit.test_test_bench import Entity  # pylint: disable=import-outside-toplevel
        from vunit.sim_if.ghdl import GHDLInterface  # pylint: disable=import-outside-toplevel
        from vunit.project import Project  # pylint: disable=import-outside-toplevel
        from vunit.configuration import Configuration  # pylint: disable=import-outside-toplevel
        from vunit.vhdl_standard import VHDL  # pylint: disable=import-outside-toplevel

        design_unit = Entity("tb_entity", file_name=str(Path("tempdir") / "file.vhd"))
        design_unit.original_file_name = str(Path("tempdir") / "other_path" / "original_file.vhd")
        design_unit.generic_names = ["runner_cfg", "tb_path"]
        config = Configuration("name", design_unit)

        for backend, expect_flag in (("llvm", True), ("gcc", True), ("mcode", False), ("llvm-jit", False)):
            with mock.patch.object(GHDLInterface, "determine_version", return_value=5.0):
                simif = GHDLInterface(prefix="prefix", output_path="", backend=backend)
            simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access
            simif._project = Project()  # pylint: disable=protected-access
            simif._project.add_library("lib", "lib_path")  # pylint: disable=protected-access

            bridge = bridge_setup.PythonBridge(
                library_file=Path("/bridge/dir/libvunit_python_bridge.so"), vhdl_files=[]
            )
            bridge_setup._BRIDGES[simif._project] = bridge  # pylint: disable=protected-access
            try:
                cmd = simif._get_command(  # pylint: disable=protected-access
                    config, str(Path("output_path") / "ghdl"), True, False, "tb_entity", None
                )
            finally:
                bridge_setup._BRIDGES.pop(simif._project, None)  # pylint: disable=protected-access

            flag = f"-Wl,-L{Path('/bridge/dir')!s}"
            if expect_flag:
                self.assertIn(flag, cmd, f"backend={backend}")
            else:
                self.assertNotIn(flag, cmd, f"backend={backend}")

    def test_nvc_simulate_loads_bridge_after_dash_r(self):
        from vunit.sim_if.nvc import NVCInterface  # pylint: disable=import-outside-toplevel
        from tests.unit.test_test_bench import Entity  # pylint: disable=import-outside-toplevel
        from vunit.project import Project  # pylint: disable=import-outside-toplevel
        from vunit.configuration import Configuration  # pylint: disable=import-outside-toplevel
        from vunit.vhdl_standard import VHDL  # pylint: disable=import-outside-toplevel

        design_unit = Entity("tb_entity", file_name=str(Path("tempdir") / "file.vhd"))
        design_unit.original_file_name = str(Path("tempdir") / "other_path" / "original_file.vhd")
        design_unit.generic_names = ["runner_cfg", "tb_path"]
        config = Configuration("name", design_unit)

        with create_tempdir() as tempdir:
            with mock.patch.object(NVCInterface, "determine_version", return_value=(1, 99)):
                simif = NVCInterface(output_path=str(tempdir), prefix="prefix", num_threads=1)
            simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access
            simif._project = Project()  # pylint: disable=protected-access
            simif._project.add_library("lib", str(tempdir))  # pylint: disable=protected-access

            bridge = bridge_setup.PythonBridge(
                library_file=Path("/bridge/dir/libvunit_python_bridge.so"), vhdl_files=[]
            )
            bridge_setup._BRIDGES[simif._project] = bridge  # pylint: disable=protected-access

            captured = {}

            class _FakeProcess:
                def __init__(self, cmd, env=None):
                    captured["cmd"] = cmd

                def consume_output(self):
                    pass

            try:
                with mock.patch("vunit.sim_if.nvc.Process", _FakeProcess):
                    simif.simulate(str(tempdir), "tb_entity", config, elaborate_only=False)
            finally:
                bridge_setup._BRIDGES.pop(simif._project, None)  # pylint: disable=protected-access

            cmd = captured["cmd"]
            self.assertIn("-r", cmd)
            load = f"--load={Path('/bridge/dir/libvunit_python_bridge.so')!s}"
            self.assertIn(load, cmd)
            self.assertGreater(cmd.index(load), cmd.index("-r"))

    def test_nvc_simulate_has_no_load_flag_without_bridge(self):
        from vunit.sim_if.nvc import NVCInterface  # pylint: disable=import-outside-toplevel
        from tests.unit.test_test_bench import Entity  # pylint: disable=import-outside-toplevel
        from vunit.project import Project  # pylint: disable=import-outside-toplevel
        from vunit.configuration import Configuration  # pylint: disable=import-outside-toplevel
        from vunit.vhdl_standard import VHDL  # pylint: disable=import-outside-toplevel

        design_unit = Entity("tb_entity", file_name=str(Path("tempdir") / "file.vhd"))
        design_unit.original_file_name = str(Path("tempdir") / "other_path" / "original_file.vhd")
        design_unit.generic_names = ["runner_cfg", "tb_path"]
        config = Configuration("name", design_unit)

        with create_tempdir() as tempdir:
            with mock.patch.object(NVCInterface, "determine_version", return_value=(1, 99)):
                simif = NVCInterface(output_path=str(tempdir), prefix="prefix", num_threads=1)
            simif._vhdl_standard = VHDL.standard("2008")  # pylint: disable=protected-access
            simif._project = Project()  # pylint: disable=protected-access
            simif._project.add_library("lib", str(tempdir))  # pylint: disable=protected-access

            captured = {}

            class _FakeProcess:
                def __init__(self, cmd, env=None):
                    captured["cmd"] = cmd

                def consume_output(self):
                    pass

            with mock.patch("vunit.sim_if.nvc.Process", _FakeProcess):
                simif.simulate(str(tempdir), "tb_entity", config, elaborate_only=False)

            self.assertFalse(any(flag.startswith("--load=") for flag in captured["cmd"]))


class TestForeignApplicationBuild(unittest.TestCase):
    """
    The VHPI application is built under the output path once and rebuilt when its inputs change.
    """

    @staticmethod
    def _simulator(prefix):
        simulator = mock.Mock()
        simulator.name = "rivierapro"
        simulator.find_prefix.return_value = str(prefix)
        return simulator

    def test_builds_once_and_rebuilds_when_the_fingerprint_changes(self):
        with create_tempdir() as tempdir:
            output_path = Path(tempdir) / "out"
            simulator = self._simulator(Path(tempdir) / "rivierapro" / "bin")
            target = output_path / "rivierapro" / "libraries" / "python.dll"

            def fake_build(target, sources, simulator_prefix):  # pylint: disable=unused-argument
                target.write_text("built", encoding="utf-8")

            with mock.patch.object(foreign_application, "_build_vhpi", side_effect=fake_build) as build:
                foreign_application.setup_vhpi_application(output_path, simulator)
                foreign_application.setup_vhpi_application(output_path, simulator)
            self.assertEqual(build.call_count, 1)
            self.assertTrue(target.exists())
            self.assertTrue(target.with_suffix(".dll.fingerprint").exists())

            # Another simulator installation changes the fingerprint
            other = self._simulator(Path(tempdir) / "other" / "bin")
            with mock.patch.object(foreign_application, "_build_vhpi", side_effect=fake_build) as build:
                foreign_application.setup_vhpi_application(output_path, other)
            self.assertEqual(build.call_count, 1)

            # A missing library is rebuilt even with a matching fingerprint
            target.unlink()
            with mock.patch.object(foreign_application, "_build_vhpi", side_effect=fake_build) as build:
                foreign_application.setup_vhpi_application(output_path, other)
            self.assertEqual(build.call_count, 1)

    def test_failed_build_leaves_no_fingerprint(self):
        with create_tempdir() as tempdir:
            output_path = Path(tempdir) / "out"
            simulator = self._simulator(Path(tempdir) / "rivierapro" / "bin")
            with mock.patch.object(foreign_application, "_build_vhpi", side_effect=RuntimeError("boom")):
                with self.assertRaises(RuntimeError):
                    foreign_application.setup_vhpi_application(output_path, simulator)
            self.assertFalse(list((output_path / "rivierapro" / "libraries").glob("*.fingerprint")))


if __name__ == "__main__":
    unittest.main()

