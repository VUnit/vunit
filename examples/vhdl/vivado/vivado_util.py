# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2018, Lars Asplund lars.anders.asplund@gmail.com

from subprocess import check_call
import os
from os.path import join, exists, abspath, dirname, basename
from os import makedirs
from vunit.simulator_factory import SIMULATOR_FACTORY


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
    compile_project_ip(vunit_obj, project_file, project_ip_path)


def compile_project_ip(vunit_obj, project_file, output_path):
    """
    Compile xci ip within vivado project file
    returns a list of library logical names and paths
    """
    compile_order_file = join(output_path, "compile_order.txt")

    if not exists(compile_order_file):
        print("Generating Vivado project compile order into %s ..." % abspath(compile_order_file))

        if not exists(output_path):
            makedirs(output_path)

        print("Extracting compile order ...")
        run_vivado(join(dirname(__file__), "tcl", "extract_compile_order.tcl"), project_file, compile_order_file)

    compile_order, libraries, include_dirs = read_compile_order(compile_order_file)

    # Create libraries
    for library_name in libraries:
        vunit_obj.add_library(library_name, vhdl_standard="93")

    # Add all source files to VUnit
    previous_source = None
    for library_name, file_name in compile_order:
        is_verilog = file_name.endswith(".v") or file_name.endswith(".vp")

        source_file = vunit_obj.library(library_name).add_source_file(
            file_name,

            # Top level IP files are put in xil_defaultlib and can be scanned for dependencies by VUnit
            # Files in other libraries are typically encrypted and are not parsed
            no_parse=library_name != "xil_defaultlib",
            include_dirs=include_dirs if is_verilog else None)

        source_file.add_compile_option("rivierapro.vcom_flags", ["-dbg"])
        source_file.add_compile_option("rivierapro.vlog_flags", ["-dbg"])

        # Create linear dependency on Vivado IP files to match extracted compile order
        if previous_source is not None:
            source_file.add_dependency_on(previous_source)

        previous_source = source_file


def is_verilog_header(file_name):
    """
    Vivado uses *_support.v for headers instead of .vh in some places
    """
    return file_name.endswith(".vh") or file_name.endswith("_support.v") or file_name.endswith("_defines.v")


def read_compile_order(file_name):
    """
    Read the compile order file and filter out duplicate files
    """
    compile_order = []
    unique = set()
    include_dirs = set()
    libraries = set()

    with open(file_name, "r") as ifile:

        for line in ifile.readlines():
            library_name, file_name = line.strip().split(",")
            libraries.add(library_name)

            # Vivado generates duplicate files for different IP:s
            # using the same underlying libraries. We remove duplicates here
            key = (library_name, basename(file_name))
            if key in unique:
                continue
            unique.add(key)

            if is_verilog_header(file_name):
                include_dirs.add(dirname(file_info.file_name))
            else:
                compile_order.append((library_name, file_name))

    return compile_order, libraries, list(include_dirs)


def compile_standard_libraries(vunit_obj, output_path):
    """
    Compile Xilinx standard libraries using Vivado TCL command
    """
    done_token = join(output_path, "all_done.txt")

    if not exists(done_token):
        print("Compiling standard libraries into %s ..." % abspath(output_path))
        simname = SIMULATOR_FACTORY.simulator_name

        # Vivado calls rivierapro for riviera
        if simname == "rivierapro":
            simname = "riviera"

        run_vivado(join(dirname(__file__), "tcl", "compile_standard_libs.tcl"),
                   simname,
                   SIMULATOR_FACTORY._simulator_class.find_prefix().replace("\\", "/"),
                   output_path)

    else:
        print("Standard libraries already exists in %s, skipping" % abspath(output_path))

    for library_name in ["unisim", "unimacro", "unifast", "secureip", "xpm"]:
        path = join(output_path, library_name)
        if exists(path):
            vunit_obj.add_external_library(library_name, path)

    with open(done_token, "w") as fptr:
        fptr.write("done")


def run_vivado(tcl_file_name, *args):
    """
    Run tcl script in vivado in batch mode.

    Note: the shell=True is important in windows where Vivado is just a bat file.
    """
    cmd = "vivado -mode batch -notrace -nojournal -nolog -source %s -tclargs %s" % (tcl_file_name, " ".join(args))
    print(cmd)
    check_call(cmd, shell=True)
