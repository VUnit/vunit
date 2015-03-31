# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from subprocess import check_call
from os.path import join, exists, abspath
from os import makedirs


def run_vivado(tcl_file_name, *args):
    """
    Run tcl script in vivado in batch mode.

    Note: the shell=True is important in windows where Vivado is just a bat file.
    """
    cmd = "vivado -mode batch -nojournal -nolog -source %s -tclargs %s" % (tcl_file_name, " ".join(args))
    print(cmd)
    check_call(cmd, shell=True)


def create_library(library_name, library_path, cwd):
    """
    Create library, modelsim specific
    """
    print("Creating library %s in %s" % (library_name, library_path))
    check_call(['vlib', '-unix', library_path])
    check_call(['vmap', library_name, abspath(library_path)], cwd=cwd)


def compile_file(file_name, library_name, cwd):
    """
    Create file, modelsim specific
    """
    print("Compiling %s" % file_name)
    check_call(['vcom', '-quiet', '-work', library_name, abspath(file_name)], cwd=cwd)


def compile_unisim(library_path):
    """
    Compile unisim library
    """
    unisim_src_path = "/opt/Xilinx/Vivado/2014.3/data/vhdl/src/unisims/"

    create_library("unisim", library_path, library_path)
    compile_file(join(unisim_src_path, "unisim_VPKG.vhd"), "unisim", library_path)
    compile_file(join(unisim_src_path, "unisim_VCOMP.vhd"), "unisim", library_path)

    with open(join(unisim_src_path, "primitive", "vhdl_analyze_order"), "r") as unisim_order_file:
        analyze_order = [line.strip() for line in unisim_order_file.readlines()]
        for file_base_name in analyze_order:
            file_name = join(unisim_src_path, "primitive", file_base_name)
            if not exists(file_name):
                continue
            compile_file(file_name, "unisim", library_path)


def compile_vivado_ip(root, project_file, unisim_library_path):
    """
    Compile xci ip within vivado project file
    returns a list of library logical names and paths
    """
    compiled_ip_path = join(root, "compiled_ip")
    compiled_libraries_file = join(compiled_ip_path, "libraries.txt")
    compile_order_file = join(compiled_ip_path, "compile_order.txt")

    def get_compile_order():
        print("Extracting compile order ...")
        run_vivado(join(root, "tcl", "extract_compile_order.tcl"), project_file, compile_order_file)
        with open(compile_order_file, "r") as ifile:
            return [line.strip().split(",") for line in ifile.readlines()]

    if not exists(compiled_libraries_file):
        print("Compiling vivado project ip into %s ..." % abspath(compiled_ip_path))
        if not exists(compiled_ip_path):
            makedirs(compiled_ip_path)

        compile_order = get_compile_order()
        libraries = set(library_name for library_name, _ in compile_order)

        # Map already compiled unisim library
        create_library("unisim", unisim_library_path, compiled_ip_path)

        # Map vivado project ip libraries
        for library_name in libraries:
            library_path = join(compiled_ip_path, library_name)
            create_library(library_name, library_path, compiled_ip_path)

        # Compile vivado project ip files
        for library_name, file_name in compile_order:
            compile_file(file_name, library_name, compiled_ip_path)

        # Write libraries to file to cache the result
        with open(compiled_libraries_file, "w") as ofile:
            for library_name in libraries:
                library_path = join(compiled_ip_path, library_name)
                ofile.write("%s,%s\n" % (library_name, library_path))
    else:
        print("Vivado project ip already compiled in %s, skipping" % abspath(compiled_ip_path))

    with open(compiled_libraries_file, "r") as ifile:
        lines = ifile.read().splitlines()
        return [line.split(",") for line in lines]


def add_vivado_ip(vu, root, project_file):
    """
    Add vivado (and compile if necessary) vivado ip to vunit project.
    """

    if not exists(project_file):
        print("Could not find vivado project %s" % project_file)
        exit(1)

    unisim_library_path = join(root, "unisim")

    # For this example we compile unisim our selves
    # In a real use case it is probably better to use the simulation library wizard
    # NOTE: To compile some IP:s more libraries than unsim might be required...
    if not exists(unisim_library_path):
        print("Compiling unisim library into %s ..." % abspath(unisim_library_path))
        compile_unisim(unisim_library_path)
    else:
        print("unisim library already exists in %s, skipping" % abspath(unisim_library_path))

    libraries = compile_vivado_ip(root, project_file, unisim_library_path)
    for library_name, library_path in libraries:
        vu.add_external_library(library_name, library_path)
    vu.add_external_library("unisim", unisim_library_path)
