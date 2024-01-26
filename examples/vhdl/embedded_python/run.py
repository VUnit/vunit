# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit
from vunit.python_pkg import compile_vhpi_application, compile_fli_application


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
    vu.enable_location_preprocessing()
    simulator_name = vu.get_simulator_name()

    if simulator_name in ["rivierapro", "activehdl"]:
        # TODO: Include VHPI application compilation in VUnit
        # NOTE: A clean build will delete the output after it was created so another no clean build has to be performed.
        compile_vhpi_application(root, vu)
    elif simulator_name == "modelsim":
        compile_fli_application(root, vu)

    lib = vu.add_library("lib")
    lib.add_source_files(root / "*.vhd")

    vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
    vu.set_sim_option("rivierapro.vsim_flags", ["-interceptcoutput"])
    # Crashes RPRO for some reason. TODO: Fix when the C code is properly
    # integrated into the project. Must be able to debug the C code.
    # vu.set_sim_option("rivierapro.vsim_flags" , ["-cdebug"])

    vu.main()


if __name__ == "__main__":
    main()
