# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
import subprocess
import sys
from multiprocessing import Manager, Process, get_context, Queue
from vunit import VUnit


def ccomp(simulator_name):
  root = Path(__file__).parent
  path_to_shared_lib = root / "vunit_out" / simulator_name / "libraries" / "python"
  if not path_to_shared_lib.exists():
      path_to_shared_lib.mkdir(parents=True, exist_ok=True)
  path_to_python_include = Path(sys.executable).parent / "include"
  path_to_python_libs = Path(sys.executable).parent / "libs"
  python_shared_lib = f"python{sys.version_info[0]}{sys.version_info[1]}"
  path_to_cpp_file = root / ".." / ".." / ".." / "vunit" / "vhdl" / "python" / "src" / "python.cpp"

  proc = subprocess.run(
    [
      "ccomp",
      "-vhpi",
      "-dbg",
      "-verbose",
      "-o",
      '"' + str(path_to_shared_lib) + '"',
      "-l",
      python_shared_lib,
      "-l",
      "_tkinter",
      "-I",
      '"' + str(path_to_python_include) + '"',
      "-L",
      '"' + str(path_to_python_libs) + '"',
      '"' + str(path_to_cpp_file) + '"',
    ],
    capture_output=True,
    text=True,
    check=False,
  )

  if proc.returncode != 0:
      print(proc.stdout)
      print(proc.stderr)
      raise RuntimeError("Failed to compile VHPI application")


def remote_test():
  return 2


def remote_test2():
  return 3


def remote_test3():
  return 4


def actor():
    print("Actor started")


def init_actor():
  print("Init actor")

  ctx = get_context('spawn')
  proc = ctx.Process(target=actor)
  try:
    proc.start()
  except Exception as exc:
    print(exc)


def hello_world():
    print("Hello World")


class Plot():

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
    line, = plt.plot(x_vector, y_vector, 'r-')
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

  # TODO: Include VHPI application compilation in VUnit
  # NOTE: A clean build will delete the output after it was created so another no clean build has to be performed.
  ccomp(vu.get_simulator_name())

  lib = vu.add_library("lib")
  lib.add_source_files(root / "*.vhd")

  vu.set_compile_option("rivierapro.vcom_flags" , ["-dbg"])
  vu.set_sim_option("rivierapro.vsim_flags" , ["-interceptcoutput"])
  # Crashes RPRO for some reason. TODO: Fix when the C code is properly
  # integrated into the project. Must be able to debug the C code.
  # vu.set_sim_option("rivierapro.vsim_flags" , ["-cdebug"])

  vu.main()


if __name__ == "__main__":
  main()
