# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
External Buffer
---------------

`Interfacing with foreign languages (C) through VHPIDIRECT <https://ghdl.readthedocs.io/en/latest/using/Foreign.html>`_

An array of type ``uint8_t`` is allocated in a C application and some values
are written to the first ``1/3`` positions. Then, the VHDL simulation is
executed, where the (external) array/buffer is used.

In the VHDL testbenches, two vector pointers are created, each of them using
a different access mechanism (``extfunc`` or ``extacc``). One of them is used to copy
the first ``1/3`` elements to positions ``[1/3, 2/3)``, while incrementing each value
by one. The second one is used to copy elements from ``[1/3, 2/3)`` to ``[2/3, 3/3)``,
while incrementing each value by two.

When the simulation is finished, the C application checks whether data was successfully
copied/modified. The content of the buffer is printed both before and after the
simulation.
"""

from vunit import VUnit, ROOT
from sys import argv
from os import popen, makedirs
from os.path import join, dirname
from shutil import copyfile
import re


src_path = join(dirname(__file__), "src")
ext_srcs = join(ROOT, "vunit", "vhdl", "data_types", "src", "external", "ghdl")
build_only = False
if "--build" in argv:
    argv.remove("--build")
    build_only = True

# Compile C applications to objects
c_iobj = join(src_path, "imain.o")
c_bobj = join(src_path, "bmain.o")

for val in [["int32_t", c_iobj], ["uint8_t", c_bobj]]:
    print(
        popen(
            " ".join(
                [
                    "gcc",
                    "-fPIC",
                    "-DTYPE=" + val[0],
                    "-I",
                    ext_srcs,
                    "-c",
                    join(src_path, "main.c"),
                    "-o",
                    val[1],
                ]
            )
        ).read()
    )

# Enable the external feature for strings/byte_vectors and integer_vectors
vu = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
vu.add_builtins({"string": True, "integer": True})

lib = vu.add_library("lib")
lib.add_source_files(join(src_path, "tb_ext_*.vhd"))

# Add the C object to the elaboration of GHDL
for tb in lib.get_test_benches(pattern="*tb_ext*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + c_bobj, "-Wl,-Wl,--version-script=" + join(ext_srcs, "grt.ver")],
        overwrite=True,
    )
for tb in lib.get_test_benches(pattern="*tb_ext*_integer*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + c_iobj, "-Wl,-Wl,--version-script=" + join(ext_srcs, "grt.ver")],
        overwrite=True,
    )

if build_only:
    vu.set_sim_option("ghdl.elab_e", True)
    vu._args.elaborate = True

    def post_func(results):
        """
        Copy runtime args for each test/executable to output dir 'cosim'
        """
        report = results.get_report()
        cosim_args_dir = join(report.output_path, "cosim")
        try:
            makedirs(cosim_args_dir)
        except FileExistsError:
            pass
        for key, val in report.tests.items():
            copyfile(
                join(val.path, "ghdl", "args.json"),
                join(cosim_args_dir, "%s.json" % re.search("lib\.(.+)\.all", key)[1]),
            )

    vu.main(post_run=post_func)
else:
    vu.main()
