# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Run script of the VHDL Python package.

It is imported by tb_python_pkg through import_run_script, which is why
everything but remote_test is guarded by a __main__ check.
"""

from pathlib import Path
from vunit import VUnit, VUnitCLI

ROOT = Path(__file__).parent

# The VHPI application reports Python errors fatally rather than as failures
# on python_logger, so the negative tests of tb_python_pkg cannot mock the
# logger there and fail by design. The Python bridge (NVC, GHDL, Questa) makes
# them observable from VHDL and there the whole testbench passes.
EXPECTED_FAILURES_VHPI = [
    "lib.tb_python_pkg.Test eval of integer with overflow from Python to C",
    "lib.tb_python_pkg.Test eval of integer with underflow from Python to C",
    "lib.tb_python_pkg.Test eval of integer with overflow from C to VHDL",
    "lib.tb_python_pkg.Test eval of integer with underflow from C to VHDL",
    "lib.tb_python_pkg.Test exceptions in exec",
    "lib.tb_python_pkg.Test exceptions in eval",
    "lib.tb_python_pkg.Test eval with type error",
    "lib.tb_python_pkg.Test raising exception",
    # The VHPI application rejects real values outside the float range and has
    # no representation for a value that is not finite
    "lib.tb_python_pkg.Test eval of real with overflow from C to VHDL",
    "lib.tb_python_pkg.Test eval of real with underflow from C to VHDL",
]

# Simulators where python_pkg is implemented by the VUnit Python bridge
BRIDGE_SIMULATORS = ["nvc", "ghdl", "modelsim"]


def remote_test():
    """
    Called from VHDL to verify that the run script can be imported into the
    embedded Python interpreter.
    """
    return 2


def verify(results, expected_failures):
    """
    Accept the expected failures, and nothing else.
    """
    tests = results.get_report().tests
    expected = [name for name in expected_failures if name in tests]
    failed = sorted(name for name, test in tests.items() if test.status == "failed")

    unexpected = [name for name in failed if name not in expected]
    if unexpected:
        raise RuntimeError("Unexpected test failures:\n" + "\n".join(unexpected))

    missing = [name for name in expected if name not in failed]
    if missing:
        raise RuntimeError("Tests expected to fail but did not:\n" + "\n".join(missing))

    if expected:
        print(f"Verified {len(expected)} expected failures: {', '.join(name.split('.')[-1] for name in expected)}")


def main():
    args = VUnitCLI().parse_args()
    # The expected failures must not make the run script fail
    args.exit_0 = True
    vu = VUnit.from_args(args)
    vu.add_vhdl_builtins()
    vu.add_python()

    simulator_name = vu.get_simulator_name()
    expected_failures = [] if simulator_name in BRIDGE_SIMULATORS else list(EXPECTED_FAILURES_VHPI)

    lib = vu.add_library("lib")
    lib.add_source_file(ROOT / "test" / "tb_python_pkg.vhd")
    if simulator_name in BRIDGE_SIMULATORS:
        # The operations implemented by the Python bridge
        lib.add_source_file(ROOT / "test" / "tb_python_pkg_bridge.vhd")

    vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
    vu.set_sim_option("rivierapro.vsim_flags", ["-interceptcoutput"])

    vu.main(post_run=lambda results: verify(results, expected_failures))


if __name__ == "__main__":
    main()
