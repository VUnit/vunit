# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Functions to add builtin VHDL code to a project for compilation
"""


from os.path import join, abspath, dirname, basename
from glob import glob

VHDL_PATH = abspath(join(dirname(__file__), "vhdl"))
VERILOG_PATH = abspath(join(dirname(__file__), "verilog"))


class Builtins(object):
    """
    Manage VUnit builtins and their dependencies
    """
    def __init__(self, vunit_obj, vhdl_standard, simulator_factory):
        self._vunit_obj = vunit_obj
        self._vunit_lib = vunit_obj.add_library("vunit_lib")
        self._vhdl_standard = vhdl_standard
        self._simulator_factory = simulator_factory
        self._builtins_adder = BuiltinsAdder()

        def add(name, deps=tuple()):
            self._builtins_adder.add_type(name, getattr(self, "_add_%s" % name), deps)

        add("array_util")
        add("com")
        add("osvvm")
        add("random", ["osvvm"])

    def add(self, name, args=None):
        self._builtins_adder.add(name, args)

    def _add_files(self, pattern):
        """
        Add files with naming convention to indicate which standard is supported
        """
        supports_context = self._simulator_factory.supports_vhdl_2008_contexts() and self._vhdl_standard == "2008"

        tags = {
            "93": ("93",),
            "2002": ("2002",),
            "2008": ("2008",),
            "200x": ("2002", "2008",),
        }

        for file_name in glob(pattern):

            standards = set()
            for tag, applicable_standards in tags.items():
                if tag in basename(file_name):
                    standards.update(applicable_standards)

            if standards and self._vhdl_standard not in standards:
                continue

            if not supports_context and file_name.endswith("_context.vhd"):
                continue

            self._vunit_lib.add_source_file(file_name)

    def _add_data_types(self):
        """
        Add data types packages
        """
        self._add_files(join(VHDL_PATH, "data_types", "src", "*.vhd"))

    def _add_array_util(self):
        """
        Add array utility
        """
        if self._vhdl_standard != '2008':
            raise RuntimeError("Array util only supports vhdl 2008")

        self._vunit_lib.add_source_files(join(VHDL_PATH, "array", "src", "*.vhd"))

    def _add_random(self):
        """
        Add random pkg
        """
        if self._vhdl_standard != '2008':
            raise RuntimeError("Random only supports vhdl 2008")

        self._vunit_lib.add_source_files(join(VHDL_PATH, "random", "src", "*.vhd"))

    def _add_com(self):
        """
        Add com library
        """
        supports_context = self._simulator_factory.supports_vhdl_2008_contexts()

        if self._vhdl_standard != '2008':
            raise RuntimeError("Communication package only supports vhdl 2008")

        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_api.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_types.vhd"))
        if supports_context:
            self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_context.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_string.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_debug_codec_builder.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_support.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_messenger.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_deprecated.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_common.vhd"))
        self._vunit_lib.add_source_files(join(VHDL_PATH, "com", "src", "com_string_payload.vhd"))

    def _add_osvvm(self):
        """
        Add osvvm library
        """
        library_name = "osvvm"

        try:
            library = self._vunit_obj.library(library_name)
        except KeyError:
            library = self._vunit_obj.add_library(library_name)

        simulator_coverage_api = self._simulator_factory.get_osvvm_coverage_api()
        supports_vhdl_package_generics = self._simulator_factory.supports_vhdl_package_generics()

        if not osvvm_is_installed():
            raise RuntimeError("""
Found no OSVVM VHDL files. Did you forget to run

git submodule update --init --recursive

in your VUnit Git repository? You have to do this first if installing using setup.py.""")

        for file_name in glob(join(VHDL_PATH, "osvvm", "*.vhd")):
            if basename(file_name) == "AlertLogPkg_body_BVUL.vhd":
                continue

            if (simulator_coverage_api != "rivierapro") and (basename(file_name) == "VendorCovApiPkg_Aldec.vhd"):
                continue

            if (simulator_coverage_api == "rivierapro") and (basename(file_name) == "VendorCovApiPkg.vhd"):
                continue

            if not supports_vhdl_package_generics and (basename(file_name) in ["ScoreboardGenericPkg.vhd",
                                                                               "ScoreboardPkg_int.vhd",
                                                                               "ScoreboardPkg_slv.vhd"]):
                continue

            library.add_source_files(file_name, preprocessors=[])

    def add_verilog_builtins(self):
        """
        Add Verilog builtins
        """
        self._vunit_lib.add_source_files(join(VERILOG_PATH, "vunit_pkg.sv"))

    def add_vhdl_builtins(self, mock_lang=False, mock_log=False):
        """
        Add vunit VHDL builtin libraries
        """
        supports_context = self._simulator_factory.supports_vhdl_2008_contexts()

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
                      join("core", "src", "stop_pkg.vhd"),
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

        if self._vhdl_standard == '93':
            files += get_builtins_vhdl_93(mock_lang, mock_log)
            files += get_builtins_vhdl_not_2008()
        elif self._vhdl_standard == '2002':
            files += get_builtins_vhdl_not_93(mock_lang, mock_log)
            files += get_builtins_vhdl_not_2008()
        elif self._vhdl_standard == '2008':
            files += get_builtins_vhdl_not_93(mock_lang, mock_log)
            files += get_builtins_vhdl_2008()

        for file_name in files:
            self._vunit_lib.add_source_files(join(VHDL_PATH, file_name))

        self._add_data_types()


def osvvm_is_installed():
    """
    Checks if OSVVM is installed within the VUnit directory structure
    """
    return len(glob(join(VHDL_PATH, "osvvm", "*.vhd"))) != 0


def add_verilog_include_dir(include_dirs):
    """
    Add VUnit Verilog include directory
    """
    return [join(VERILOG_PATH, "include")] + include_dirs


class BuiltinsAdder(object):
    """
    Class to manage adding of builtins with dependencies
    """

    def __init__(self):
        self._already_added = {}
        self._types = {}

    def add_type(self, name, function, dependencies=tuple()):
        self._types[name] = (function, dependencies)

    def add(self, name, args=None):
        """
        Add builtin with arguments
        """
        args = {} if args is None else args

        if not self._add_check(name, args):
            function, dependencies = self._types[name]
            for dep_name in dependencies:
                self.add(dep_name)
            function(**args)

    def _add_check(self, name, args=None):
        """
        Check if this package has already been added,
        if it has already been added it must use the same parameters

        @returns False if not yet added
        """
        if name not in self._already_added:
            self._already_added[name] = args
            return False

        old_args = self._already_added[name]
        if args != old_args:
            raise RuntimeError(
                "Optional builtin %r added with arguments %r has already been added with arguments %r"
                % (name, args, old_args))
        return True
