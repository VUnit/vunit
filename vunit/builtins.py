# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Functions to add builtin VHDL code to a project for compilation
"""


from os.path import join, abspath, dirname, basename
from glob import glob

VHDL_PATH = abspath(join(dirname(__file__), "vhdl"))
VERILOG_PATH = abspath(join(dirname(__file__), "verilog"))


def add_verilog_builtins(library):
    """
    Add Verilog builtins
    """
    library.add_source_files(join(VERILOG_PATH, "vunit_pkg.sv"))


def add_verilog_include_dir(include_dirs):
    """
    Add VUnit Verilog include directory
    """
    return [join(VERILOG_PATH, "include")] + include_dirs


def add_vhdl_builtins(library,
                      vhdl_standard,
                      mock_lang=False,
                      mock_log=False,
                      supports_context=True):
    """
    Add vunit VHDL builtin libraries
    """
    def get_builtins_vhdl_all(mock_lang):
        """Return built-in VHDL files present under all VHDL versions"""
        files = []

        if mock_lang:
            files += [join("vhdl", "src", "lang", "lang_mock.vhd")]
            files += [join("vhdl", "src", "lang", "lang_mock_types.vhd")]
            files += [join("common", "test", "test_type_methods_api.vhd")]
        else:
            files += [join("vhdl", "src", "lang", "lang.vhd")]

        files += [join("string_ops", "src", "string_ops.vhd"),
                  join("check", "src", "check.vhd"),
                  join("check", "src", "check_api.vhd"),
                  join("check", "src", "check_base_api.vhd"),
                  join("check", "src", "check_types.vhd"),
                  join("core", "src", "stop_api.vhd"),
                  join("run", "src", "run.vhd"),
                  join("run", "src", "run_api.vhd"),
                  join("run", "src", "run_types.vhd"),
                  join("run", "src", "run_base_api.vhd")]

        files += [join("core", "src", "core_pkg.vhd")]

        files += [join("logging", "src", "log_api.vhd"),
                  join("logging", "src", "log_formatting.vhd"),
                  join("logging", "src", "log.vhd"),
                  join("logging", "src", "log_types.vhd")]

        files += [join("dictionary", "src", "dictionary.vhd")]

        files += [join("path", "src", "path.vhd")]

        return files

    def get_builtins_vhdl_93(mock_lang, mock_log):
        """Return built-in VHDL files unique fro VHDL 93"""
        files = []

        if mock_lang:
            files += [join("common", "test", "test_type_methods93.vhd")]
            files += [join("common", "test", "test_types93.vhd")]
            files += [join("vhdl", "src", "lang", "lang_mock_special_types93.vhd")]

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

        return files

    def get_builtins_vhdl_not_93(mock_lang, mock_log):
        """Return built-in VHDL files present both in VHDL 2002 and 2008"""
        files = []

        if mock_lang:
            files += [join("common", "test", "test_type_methods200x.vhd")]
            files += [join("common", "test", "test_types200x.vhd")]
            files += [join("vhdl", "src", "lang", "lang_mock_special_types200x.vhd")]

        if mock_log:
            files += [join("common", "test", "test_type_methods_api.vhd")]
            files += [join("common", "test", "test_type_methods200x.vhd")]
            files += [join("common", "test", "test_types200x.vhd")]
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

        return files

    def get_builtins_vhdl_2008():
        """Return built-in VHDL files present only in 2008"""
        files = []

        if supports_context:
            files += ["vunit_context.vhd"]
            files += ["vunit_run_context.vhd"]
        files += [join("core", "src", "stop_body_2008.vhd")]

        return files

    def get_builtins_vhdl_not_2008():
        """Return built-in VHDL files present both in VHDL 93 and 2002"""
        files = []

        files += [join("core", "src", "stop_body_93.vhd")]

        return files

    files = get_builtins_vhdl_all(mock_lang)

    if vhdl_standard == '93':
        files += get_builtins_vhdl_93(mock_lang, mock_log)
        files += get_builtins_vhdl_not_2008()
    elif vhdl_standard == '2002':
        files += get_builtins_vhdl_not_93(mock_lang, mock_log)
        files += get_builtins_vhdl_not_2008()
    elif vhdl_standard == '2008':
        files += get_builtins_vhdl_not_93(mock_lang, mock_log)
        files += get_builtins_vhdl_2008()

    for file_name in files:
        library.add_source_files(join(VHDL_PATH, file_name))


def add_array_util(library, vhdl_standard):
    """
    Add array_pkg utility library
    """
    if vhdl_standard != '2008':
        raise RuntimeError("Array utility only supports vhdl 2008")

    library.add_source_files(join(VHDL_PATH, "array", "src", "array_pkg.vhd"))


def osvvm_is_installed():
    """
    Checks if OSVVM is installed within the VUnit directory structure
    """
    return len(glob(join(VHDL_PATH, "osvvm", "*.vhd"))) != 0


def add_osvvm(library):
    """
    Add osvvm library
    """
    if not osvvm_is_installed():
        raise RuntimeError("""
Found no OSVVM VHDL files. Did you forget to run

git submodule update --init --recursive

in your VUnit Git repository? You have to do this first if installing using setup.py.""")

    for file_name in glob(join(VHDL_PATH, "osvvm", "*.vhd")):
        if basename(file_name) != 'AlertLogPkg_body_BVUL.vhd':
            library.add_source_files(file_name, preprocessors=[])


def add_com(library, vhdl_standard, use_debug_codecs=False, supports_context=True):
    """
    Add com library
    """
    if vhdl_standard != '2008':
        raise RuntimeError("Communication package only supports vhdl 2008")

    library.add_source_files(join(VHDL_PATH, "com", "src", "com.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_api.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_types.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_codec_api.vhd"))
    if supports_context:
        library.add_source_files(join(VHDL_PATH, "com", "src", "com_context.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_string.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_debug_codec_builder.vhd"))
    library.add_source_files(join(VHDL_PATH, "com", "src", "com_std_codec_builder.vhd"))

    if use_debug_codecs:
        library.add_source_files(join(VHDL_PATH, "com", "src", "com_codec_debug.vhd"))
    else:
        library.add_source_files(join(VHDL_PATH, "com", "src", "com_codec.vhd"))
