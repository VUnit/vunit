# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Embedded Python
---------------

Demonstrates calling Python from VHDL with ``add_python()``: executing Python
code and calling Python functions, for example NumPy/Matplotlib reference
models, from a testbench. The test cases cover ``exec`` and ``eval`` with the
types they convert, calls with positional, keyword and keyword group
arguments, wide ``unsigned``/``signed`` and ``std_ulogic`` argument values, an
``integer_array_t`` image shared with NumPy, Python files executed with
``exec_file`` or imported with ``import_module_from_file``, two models loaded
into a session each, error reporting, and ``python_model``, a verification
component whose behaviour is a Python function. Some tests need Python
packages VUnit does not depend on (``PySimpleGUI``, ``python-constraint``,
``crccheck`` and ``matplotlib``); the run script says which when they are
missing. Three tests demonstrate error reporting and fail by design. See
:ref:`python_bridge`.
"""

import importlib.util
from pathlib import Path
from vunit import VUnit

# Test, the module it imports and the package that provides it
OPTIONAL_PACKAGES = [
    ("Test GUI browsing for input stimuli file", "PySimpleGUI", "PySimpleGUI"),
    ("Test querying for randomization seed", "PySimpleGUI", "PySimpleGUI"),
    ("Test controlling progress of simulation", "PySimpleGUI", "PySimpleGUI"),
    ("Test constraint solving", "constraint", "python-constraint"),
    ("Test using a Python module as the golden reference", "crccheck", "crccheck"),
    ("Test using Python in an behavioral model", "crccheck", "crccheck"),
    ("Test simple plot", "matplotlib", "matplotlib"),
    ("Test advanced plot", "matplotlib", "matplotlib"),
]


def missing_package(test_name, package):
    """
    A pre_config hook failing the test with the package it needs.
    """

    def pre_config(output_path):  # pylint: disable=unused-argument
        print(f"{test_name} needs the Python package {package}: pip install {package}")
        return False

    return pre_config


def hello_world():
    print("Hello World")


class Plot:

    def __init__(self, x_points, y_limits, title, x_label, y_label):
        from matplotlib import pyplot as plt

        # Create plot with a line based on x and y vectors before they have been calculated
        # Starting with an uncalculated line and updating it as we calculate more points
        # is a trick to make the rendering of the plot quicker. This is not a bottleneck
        # created by the VHDL package but inherent to the Python matplotlib package.
        fig = plt.figure()
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        plt.title(title)
        plt.xlim(x_points[0], x_points[-1])
        plt.ylim(*y_limits)
        x_vector = [x_points[0]] * len(x_points)
        y_vector = [(y_limits[0] + y_limits[1]) / 2] * len(x_points)
        (line,) = plt.plot(x_vector, y_vector, "r-")
        fig.canvas.draw()
        fig.canvas.flush_events()
        plt.show(block=False)

        self.plt = plt
        self.fig = fig
        self.x_vector = x_vector
        self.y_vector = y_vector
        self.line = line

    def update(self, x, y):
        self.x_vector[x] = x
        self.y_vector[x] = y
        self.line.set_xdata(self.x_vector)
        self.line.set_ydata(self.y_vector)
        self.fig.canvas.draw()
        self.fig.canvas.flush_events()

    def close(self):
        # Some extra code to allow showing the plot without blocking
        # the test indefinitely if window isn't closed.
        timer = self.fig.canvas.new_timer(interval=5000)
        timer.add_callback(self.plt.close)
        timer.start()
        self.plt.show()


def main():
    root = Path(__file__).parent

    vu = VUnit.from_argv()
    vu.add_vhdl_builtins()
    vu.add_python()
    vu.add_random()
    # add_python() builds the foreign language application of the simulator
    # (the Python bridge, or the VHPI application) under the output path.

    lib = vu.add_library("lib")
    lib.add_source_files(root / "*.vhd")

    vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
    vu.set_sim_option("rivierapro.vsim_flags", ["-interceptcoutput"])
    # Crashes RPRO for some reason. TODO: Fix when the C code is properly
    # integrated into the project. Must be able to debug the C code.
    # vu.set_sim_option("rivierapro.vsim_flags" , ["-cdebug"])

    tb = lib.test_bench("tb_example")

    # These tests need Python packages that VUnit does not depend on. A test
    # whose package is missing fails at once with a message saying what to
    # install; --without-attributes .optional_deps leaves them all out.
    missing = {}
    for test_name, module, package in OPTIONAL_PACKAGES:
        test = tb.test(test_name)
        test.set_attribute(".optional_deps", None)
        if importlib.util.find_spec(module) is None:
            missing.setdefault(package, []).append(test_name)
            test.set_pre_config(missing_package(test_name, package))
    if missing:
        print("Some tests need Python packages that are not installed:")
        for package, test_names in missing.items():
            print(f"  {package}: {', '.join(test_names)}")
        print(f"Install them with: pip install {' '.join(missing)}")
        print("or leave those tests out with: --without-attributes .optional_deps\n")

    # These tests demonstrate error reporting and fail by design;
    # --without-attributes .expected_failure leaves them out.
    for test_name in (
        "Test syntax error",
        "Test type error",
        "Test Python exception",
    ):
        tb.test(test_name).set_attribute(".expected_failure", None)

    vu.main()


if __name__ == "__main__":
    main()
