# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Functions to add builtin VHDL code to a project for compilation
"""


from os.path import join, abspath, dirname, basename
from glob import glob

VHDL_PATH = abspath(join(dirname(__file__), "..", "vhdl"))


def add_builtins(library, vhdl_standard, mock_lang=False, mock_log=False):
    """
    Add vunit builtin libraries
    """
    files = []

    if mock_lang:
        files += [join("vhdl", "src", "lang", "lang_mock.vhd")]
    else:
        files += [join("vhdl", "src", "lang", "lang.vhd")]

    files += [join("vhdl", "src", "lib", "std", "textio.vhd"),
              join("string_ops", "src", "string_ops.vhd"),
              join("check", "src", "check.vhd"),
              join("check", "src", "check_api.vhd"),
              join("check", "src", "check_base_api.vhd"),
              join("check", "src", "check_types.vhd"),
              join("run", "src", "stop_api.vhd"),
              join("run", "src", "run.vhd"),
              join("run", "src", "run_api.vhd"),
              join("run", "src", "run_types.vhd"),
              join("run", "src", "run_base_api.vhd")]

    files += [join("logging", "src", "log_api.vhd"),
              join("logging", "src", "log_formatting.vhd"),
              join("logging", "src", "log.vhd"),
              join("logging", "src", "log_types.vhd")]

    files += [join("dictionary", "src", "dictionary.vhd")]

    files += [join("path", "src", "path.vhd")]

    if vhdl_standard == '2008':
        files += [join("run", "src", "stop_body_2008.vhd")]
    else:
        files += [join("run", "src", "stop_body_dummy.vhd")]

    if vhdl_standard == '93':
        if mock_log:
            files += [join("logging", "src", "log_base93_mock.vhd"),
                      join("logging", "src", "log_special_types93.vhd"),
                      join("logging", "src", "log_base_api_mock.vhd")]
        else:
            files += [join("logging", "src", "log_base93.vhd"),
                      join("logging", "src", "log_special_types93.vhd"),
                      join("logging", "src", "log_base_api.vhd")]

        files += [join("check", "src", "check_base93.vhd"),
                  join("check", "src", "check_special_types93.vhd"),
                  join("run", "src", "run_base93.vhd"),
                  join("run", "src", "run_special_types93.vhd")]

    elif vhdl_standard in ('2002', '2008'):
        if mock_log:
            files += [join("logging", "src", "log_base.vhd"),
                      join("logging", "src", "log_special_types200x_mock.vhd"),
                      join("logging", "src", "log_base_api.vhd")]
        else:
            files += [join("logging", "src", "log_base.vhd"),
                      join("logging", "src", "log_special_types200x.vhd"),
                      join("logging", "src", "log_base_api.vhd")]

        files += [join("check", "src", "check_base.vhd"),
                  join("check", "src", "check_special_types200x.vhd"),
                  join("run", "src", "run_base.vhd"),
                  join("run", "src", "run_special_types200x.vhd")]

        if vhdl_standard == '2008':
            files += ["vunit_context.vhd"]

    for file_name in files:
        library.add_source_files(join(VHDL_PATH, file_name))


def add_array_util(library, vhdl_standard):
    """
    Add array_pkg utility library
    """
    if vhdl_standard != '2008':
        raise RuntimeError("Array utility only supports vhdl 2008")

    library.add_source_files(join(VHDL_PATH, "array", "src", "array_pkg.vhd"))


def add_osvvm(library):
    """
    Add osvvm library
    """
    for file_name in glob(join(VHDL_PATH, "osvvm", "*.vhd")):
        if basename(file_name) != 'AlertLogPkg_body_BVUL.vhd':
            library.add_source_files(file_name, preprocessors=[])


def add_com(library, vhdl_standard):
    """
    Add com library
    """
    if vhdl_standard != '2008':
        raise RuntimeError("Communication package only supports vhdl 2008")

    library.add_source_files(join(VHDL_PATH, "com", "src", "*.vhd"))
