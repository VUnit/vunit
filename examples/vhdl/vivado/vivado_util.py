# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from __future__ import print_function
from subprocess import check_call
import os
from os.path import join, exists, abspath, dirname, basename
from os import makedirs
from vunit.simulator_factory import SIMULATOR_FACTORY
from vunit.vivado import (run_vivado,
                          add_from_compile_order_file,
                          create_compile_order_file)


def add_vivado_ip(vunit_obj, output_path, project_file):
    """
    Add vivado (and compile if necessary) vivado ip to vunit project.
    """

    if not exists(project_file):
        print("Could not find vivado project %s" % project_file)
        exit(1)

    standard_library_path = join(output_path, "standard")
    compile_standard_libraries(vunit_obj, standard_library_path)

    project_ip_path = join(output_path, "project_ip")
    add_project_ip(vunit_obj, project_file, project_ip_path)


def compile_standard_libraries(vunit_obj, output_path):
    """
    Compile Xilinx standard libraries using Vivado TCL command
    """
    done_token = join(output_path, "all_done.txt")

    simulator_class = SIMULATOR_FACTORY.select_simulator()

    if not exists(done_token):
        print("Compiling standard libraries into %s ..." % abspath(output_path))
        simname = simulator_class.name

        # Vivado calls rivierapro for riviera
        if simname == "rivierapro":
            simname = "riviera"

        run_vivado(join(dirname(__file__), "tcl", "compile_standard_libs.tcl"),
                   tcl_args=[simname,
                             simulator_class.find_prefix().replace("\\", "/"),
                             output_path])

    else:
        print("Standard libraries already exists in %s, skipping" % abspath(output_path))

    for library_name in ["unisim", "unimacro", "unifast", "secureip", "xpm"]:
        path = join(output_path, library_name)
        if exists(path):
            vunit_obj.add_external_library(library_name, path)

    with open(done_token, "w") as fptr:
        fptr.write("done")


def add_project_ip(vunit_obj, project_file, output_path, vivado_path=None, clean=False):
    """
    Add all IP files from Vivado project to the vunit project

    Caching is used to save time where Vivado is not called again if the compile order already exists.
    If Clean is True the compile order is always re-generated

    returns the list of SourceFile objects added
    """

    compile_order_file = join(output_path, "compile_order.txt")

    if clean or not exists(compile_order_file):
        create_compile_order_file(project_file, compile_order_file, vivado_path=vivado_path)
    else:
        print("Vivado project Compile order already exists, re-using: %s" % abspath(compile_order_file))

    return add_from_compile_order_file(vunit_obj, compile_order_file)
