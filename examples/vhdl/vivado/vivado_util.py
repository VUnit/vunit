# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

import sys
from pathlib import Path
from vunit.sim_if.factory import SIMULATOR_FACTORY
from vunit.vivado import (
    run_vivado,
    add_from_compile_order_file,
    create_compile_order_file,
)


def add_vivado_ip(vunit_obj, output_path, project_file):
    """
    Add vivado (and compile if necessary) vivado ip to vunit project.
    """

    if not Path(project_file).exists():
        print("Could not find vivado project %s" % project_file)
        sys.exit(1)

    opath = Path(output_path)

    standard_library_path = str(opath / "standard")
    compile_standard_libraries(vunit_obj, standard_library_path)

    project_ip_path = str(opath / "project_ip")
    add_project_ip(vunit_obj, project_file, project_ip_path)


def compile_standard_libraries(vunit_obj, output_path):
    """
    Compile Xilinx standard libraries using Vivado TCL command
    """
    done_token = Path(output_path) / "all_done.txt"

    simulator_class = SIMULATOR_FACTORY.select_simulator()

    if not done_token.exists():
        print("Compiling standard libraries into %s ..." % str(Path(output_path).resolve()))
        simname = simulator_class.name

        # Vivado calls rivierapro for riviera
        if simname == "rivierapro":
            simname = "riviera"

        run_vivado(
            str(Path(__file__).parent / "tcl" / "compile_standard_libs.tcl"),
            tcl_args=[
                simname,
                simulator_class.find_prefix().replace("\\", "/"),
                output_path,
            ],
        )

    else:
        print("Standard libraries already exists in %s, skipping" % str(Path(output_path).resolve()))

    for library_name in ["unisim", "unimacro", "unifast", "secureip", "xpm"]:
        path = str(Path(output_path) / library_name)
        if Path(path).exists():
            vunit_obj.add_external_library(library_name, path)

    with done_token.open("w") as fptr:
        fptr.write("done")


def add_project_ip(vunit_obj, project_file, output_path, vivado_path=None, clean=False):
    """
    Add all IP files from Vivado project to the vunit project

    Caching is used to save time where Vivado is not called again if the compile order already exists.
    If Clean is True the compile order is always re-generated

    returns the list of SourceFile objects added
    """

    compile_order_file = str(Path(output_path) / "compile_order.txt")

    if clean or not Path(compile_order_file).exists():
        create_compile_order_file(project_file, compile_order_file, vivado_path=vivado_path)
    else:
        print("Vivado project Compile order already exists, re-using: %s" % str(Path(compile_order_file).resolve()))

    return add_from_compile_order_file(vunit_obj, compile_order_file)
