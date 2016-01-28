# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Acceptance test of the VUnit public interface class
"""


import unittest
from string import Template
from os.path import join, dirname, basename, exists
import os
import re
from shutil import rmtree
from re import MULTILINE
from vunit.ui import VUnit
from vunit.project import VHDL_EXTENSIONS, VERILOG_EXTENSIONS
from vunit.test.mock_2or3 import mock
from vunit.ostools import renew_path


class TestUi(unittest.TestCase):
    """
    Testing the VUnit public interface class
    """
    def setUp(self):
        self.tmp_path = join(dirname(__file__), "test_ui_tmp")
        renew_path(self.tmp_path)
        self.cwd = os.getcwd()
        os.chdir(self.tmp_path)

        self._output_path = join(self.tmp_path, 'output')
        self._preprocessed_path = join(self._output_path, "preprocessed")
        self.mocksim = None

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.tmp_path):
            rmtree(self.tmp_path)

    def test_global_custom_preprocessors_should_be_applied_in_the_order_they_are_added(self):
        ui = self._create_ui()
        ui.add_preprocessor(VUnitfier())
        ui.add_preprocessor(ParentalControl())

        file_name = self.create_entity_file()
        ui.add_source_files(file_name, 'lib')

        pp_source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    log("Here I am!"); -- VUnitfier preprocessor: Report turned of[BEEP]eeping original code.
end architecture;
""")
        with open(join(self._preprocessed_path, 'lib', basename(file_name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='ent0', file=basename(file_name)))

    def test_global_check_and_location_preprocessors_should_be_applied_after_global_custom_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        file_name = self.create_entity_file()
        ui.add_source_files(file_name, 'lib')

        pp_source = Template("""\
-- check_relation(a = b, line_num => 1, file_name => "$file", \
auto_msg => "Relation a = b failed! Left is " & to_string(a) & ". Right is " & to_string(b) & ".");

library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World", line_num => 11, file_name => "$file");
    check_relation(1 /= 2, line_num => 12, file_name => "$file", \
auto_msg => "Relation 1 /= 2 failed! Left is " & to_string(1) & ". Right is " & to_string(2) & ".");
    report "Here I am!";
end architecture;
""")
        with open(join(self._preprocessed_path, 'lib', basename(file_name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='ent0', file=basename(file_name)))

    def test_locally_specified_preprocessors_should_be_used_instead_of_any_globally_defined_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)

        ui.add_source_files(file_name1, 'lib', [])
        ui.add_source_files(file_name2, 'lib', [VUnitfier()])

        pp_source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    $report
end architecture;
""")
        self.assertFalse(exists(join(self._preprocessed_path, 'lib', basename(file_name1))))
        with open(join(self._preprocessed_path, 'lib', basename(file_name2))) as fread:
            expectd = pp_source.substitute(
                entity='ent2',
                report='log("Here I am!"); -- VUnitfier preprocessor: Report turned off, keeping original code.')
            self.assertEqual(fread.read(), expectd)

    def test_supported_source_file_suffixes(self):
        """Test adding a supported filetype, of any case, is accepted."""
        ui = self._create_ui()
        accepted_extensions = VHDL_EXTENSIONS + VERILOG_EXTENSIONS
        allowable_extensions = [ext for ext in accepted_extensions]
        allowable_extensions.extend([ext.upper() for ext in accepted_extensions])
        allowable_extensions.append(VHDL_EXTENSIONS[0][0] + VHDL_EXTENSIONS[0][1].upper() +
                                    VHDL_EXTENSIONS[0][2:])  # mixed case
        for idx, ext in enumerate(allowable_extensions):
            file_name = self.create_entity_file(idx, ext)
            ui.add_source_files(file_name, 'lib')

    def test_unsupported_source_file_suffixes(self):
        """Test adding an unsupported filetype is rejected"""
        ui = self._create_ui()
        unsupported_name = "unsupported.docx"
        self.create_file(unsupported_name)
        self.assertRaises(RuntimeError, ui.add_source_files, unsupported_name, 'lib')

    def test_can_add_non_ascii_encoded_files(self):
        ui = self._create_ui()
        lib = ui.library("lib")
        lib.add_source_files(join(dirname(__file__), 'test_ui_encoding.vhd'))
        lib.entity("encoding")  # Fill raise exception of not found

    def test_exception_on_adding_zero_files(self):
        ui = self._create_ui()
        lib = ui.library("lib")
        self.assertRaisesRegexp(ValueError, "Pattern.*missing1.vhd.*",
                                lib.add_source_files, join(dirname(__file__), 'missing1.vhd'))
        self.assertRaisesRegexp(ValueError, "File.*missing2.vhd.*",
                                lib.add_source_file, join(dirname(__file__), 'missing2.vhd'))

    def test_no_exception_on_adding_zero_files_when_allowed(self):
        ui = self._create_ui()
        lib = ui.library("lib")
        lib.add_source_files(join(dirname(__file__), 'missing.vhd'), allow_empty=True)

    def test_get_source_files(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)

        self.assertEqual(len(ui.get_source_files(file_name)), 2)
        self.assertEqual(len(lib1.get_source_files(file_name)), 1)
        self.assertEqual(len(lib2.get_source_files(file_name)), 1)

        ui.get_source_file(file_name, library_name="lib1")
        ui.get_source_file(file_name, library_name="lib2")
        lib1.get_source_file(file_name)
        lib2.get_source_file(file_name)

    def test_get_source_files_errors(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)
        non_existant_name = "non_existant"

        self.assertRaisesRegexp(ValueError, ".*%s.*allow_empty.*" % non_existant_name,
                                ui.get_source_files, non_existant_name)
        self.assertEqual(len(ui.get_source_files(non_existant_name, allow_empty=True)), 0)

        self.assertRaisesRegexp(ValueError, ".*named.*%s.*multiple.*library_name.*" % file_name,
                                ui.get_source_file, file_name)

        self.assertRaisesRegexp(ValueError, ".*Found no file named.*%s'" % non_existant_name,
                                ui.get_source_file, non_existant_name)

        self.assertRaisesRegexp(ValueError, ".*Found no file named.*%s.* in library 'lib1'" % non_existant_name,
                                ui.get_source_file, non_existant_name, "lib1")

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_single_file_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.library("lib")
        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)
        file1 = lib.add_source_file(file_name1)
        file2 = lib.add_source_file(file_name2)

        add_manual_dependency.assert_has_calls([])
        file1.depends_on(file2)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      file1._source_file,
                      depends_on=file2._source_file)])

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_multiple_file_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        add_manual_dependency.assert_has_calls([])
        bar_file.depends_on(foo_files)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      bar_file._source_file,
                      depends_on=foo_file._source_file)
            for foo_file in foo_files])

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_fileset_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        add_manual_dependency.assert_has_calls([])
        foo_files.depends_on(bar_file)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      foo_file._source_file,
                      depends_on=bar_file._source_file)
            for foo_file in foo_files])

    def _test_pre_config_helper(self, retval, test_not_entity=False):
        """
        Helper method to test pre_config where the pre config can return different values
        and it can be configured on both entity and test objects
        """
        ui = self._create_ui("lib.test_ui_tb.test_one")
        lib = ui.library("lib")
        lib.add_source_files(join(dirname(__file__), 'test_ui_tb.vhd'))

        if test_not_entity:
            obj = lib.entity("test_ui_tb").test("test_one")
        else:
            obj = lib.entity("test_ui_tb")

        def side_effect():
            "No simulate calls should have occured so far"
            self.assertEqual(self.mocksim.simulate_calls, [])
            return retval

        pre_config = mock.Mock()
        pre_config.return_value = retval
        pre_config.side_effect = side_effect

        obj.add_config(name="", pre_config=pre_config)
        self._run_main(ui, 0 if retval else 1)

        pre_config.assert_has_calls([call()])

    def test_entity_has_pre_config(self):
        for retval in (True, False, None):
            self._test_pre_config_helper(retval)

    def test_test_has_pre_config(self):
        self._test_pre_config_helper(True, test_not_entity=False)

    @mock.patch("vunit.ui.LOGGER", autospec=True)
    def test_warning_on_no_tests(self, logger):
        ui = self._create_ui("--compile")
        self._run_main(ui)
        self.assertEqual(logger.warning.mock_calls, [])
        logger.reset_mock()

        ui = self._create_ui("--list")
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

        ui = self._create_ui()
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

    def _create_ui(self, *args):
        """ Create an instance of the VUnit public interface class """
        ui = VUnit.from_argv(argv=["--output-path=%s" % self._output_path,
                                   "--clean"] + list(args),
                             compile_builtins=False)
        ui.add_library('lib')

        factory = MockSimulatorFactory(self._output_path)
        self.mocksim = factory.mocksim
        ui._simulator_factory = factory  # pylint: disable=protected-access
        return ui

    def _run_main(self, ui, code=0):
        """
        Run ui.main and expect exit code
        """
        try:
            ui.main()
        except SystemExit as exc:
            self.assertEqual(exc.code, code)

    def create_entity_file(self, idx=0, file_suffix='.vhd'):
        """
        Create and a temporary file containing the same source code
        but with different entity names depending on the index
        """
        source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    report "Here I am!";
end architecture;
""")

        entity_name = "ent%i" % idx
        file_name = entity_name + file_suffix
        self.create_file(file_name,
                         source.substitute(entity=entity_name))
        return file_name

    @staticmethod
    def create_file(file_name, contents=""):
        """
        Creata file in the temporary path with given contents
        """
        with open(file_name, "w") as fptr:
            fptr.write(contents)


def call(*args, **kwargs):
    """
    To create call objects for checking calls on mock objects
    """
    return (args, kwargs)


class TestPreprocessor(object):
    """
    A preprocessor that appends a check_relation call before the orginal code
    """
    def __init__(self):
        pass

    @staticmethod
    def run(code, file_name):  # pylint: disable=unused-argument
        return '-- check_relation(a = b);\n' + code


class VUnitfier(object):
    """
    A preprocessor that replaces report statments with log calls
    """
    def __init__(self):
        self._report_pattern = re.compile(r'^(?P<indent>\s*)report\s*(?P<note>"[^"]*")\s*;', MULTILINE)

    def run(self, code, file_name):   # pylint: disable=unused-argument
        return self._report_pattern.sub(
            r'\g<indent>log(\g<note>); -- VUnitfier preprocessor: Report turned off, keeping original code.', code)


class ParentalControl(object):
    """
    A preprocessor that replaces f..k with [BEEP]
    """
    def __init__(self):
        self._fword_pattern = re.compile(r'f..k')

    def run(self, code, file_name):   # pylint: disable=unused-argument
        return self._fword_pattern.sub(r'[BEEP]', code)


class MockSimulatorFactory(object):
    """
    Mock a simulator factory
    """
    simulator_name = "mocksim"

    def __init__(self, output_path):
        self._output_path = output_path
        self.mocksim = MockSimulator()

    @property
    def simulator_output_path(self):
        return join(self._output_path, self.simulator_name)

    @staticmethod
    def package_users_depend_on_bodies():
        return True

    def create(self):
        return self.mocksim


class MockSimulator(object):
    """
    Mock a simulator
    """

    def __init__(self):
        self.simulate_calls = []

    @staticmethod
    def compile_project(project, vhdl_standard):  # pylint: disable=unused-argument
        return True

    def post_process(self, output_path):  # pylint: disable=unused-argument
        pass

    def simulate(self,   # pylint: disable=too-many-arguments
                 output_path, library_name, entity_name, architecture_name, config):
        """
        Accumulate simulation calls
        """
        self.simulate_calls.append((output_path,
                                    library_name,
                                    entity_name,
                                    architecture_name,
                                    config))
        return True
