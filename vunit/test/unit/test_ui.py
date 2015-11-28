# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Acceptance test of the VUnit public interface class
"""


import unittest
from string import Template
from tempfile import NamedTemporaryFile
from os.path import join, dirname, basename, exists
from os import remove
import re
from re import MULTILINE
from vunit.ui import VUnit
from vunit.project import VHDL_EXTENSIONS, VERILOG_EXTENSIONS
from vunit.test.mock_2or3 import mock


class TestUi(unittest.TestCase):
    """
    Testing the VUnit public interface class
    """
    def setUp(self):
        self._output_path = join(dirname(__file__), 'ui_out')
        self._preprocessed_path = join(self._output_path, "preprocessed")
        self.mocksim = None

    def tearDown(self):
        pass

    def _create_ui(self, *args):
        """ Create an instance of the VUnit public interface class """
        ui = VUnit.from_argv(argv=["--output-path=%s" % self._output_path,
                                   "--clean"] + list(args))
        ui.add_library('lib')

        factory = MockSimulatorFactory(self._output_path)
        self.mocksim = factory.mocksim
        ui._simulator_factory = factory  # pylint: disable=protected-access
        return ui

    def _create_temp_files(self, num_files, file_suffix='.vhd'):
        """
        Create and return num_files temporary files containing the
        same source code but with different entity names depending on
        the index
        """
        return [self._create_temp_file(i, file_suffix) for i in range(num_files)]

    @staticmethod
    def _create_temp_file(idx, file_suffix='.vhd'):
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

        fptr = NamedTemporaryFile(mode='w', suffix=file_suffix, delete=False)
        fptr.write(source.substitute(entity='foo%d' % idx))
        fptr.close()
        return fptr

    @staticmethod
    def _delete_temp_files(files):
        for file_obj in files:
            remove(file_obj.name)

    def test_global_custom_preprocessors_should_be_applied_in_the_order_they_are_added(self):
        ui = self._create_ui()
        ui.add_preprocessor(VUnitfier())
        ui.add_preprocessor(ParentalControl())

        files = self._create_temp_files(1)
        ui.add_source_files(files[0].name, 'lib')

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
        with open(join(self._preprocessed_path, 'lib', basename(files[0].name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='foo0', file=basename(files[0].name)))

        self._delete_temp_files(files)

    def test_global_check_and_location_preprocessors_should_be_applied_after_global_custom_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        files = self._create_temp_files(1)
        ui.add_source_files(files[0].name, 'lib')

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
        with open(join(self._preprocessed_path, 'lib', basename(files[0].name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='foo0', file=basename(files[0].name)))

        self._delete_temp_files(files)

    def test_locally_specified_preprocessors_should_be_used_instead_of_any_globally_defined_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        files = self._create_temp_files(2)

        ui.add_source_files(files[0].name, 'lib', [])
        ui.add_source_files(files[1].name, 'lib', [VUnitfier()])

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
        self.assertFalse(exists(join(self._preprocessed_path, 'lib', basename(files[0].name))))
        with open(join(self._preprocessed_path, 'lib', basename(files[1].name))) as fread:
            expectd = pp_source.substitute(
                entity='foo1',
                report='log("Here I am!"); -- VUnitfier preprocessor: Report turned off, keeping original code.')
            self.assertEqual(fread.read(), expectd)

        self._delete_temp_files(files)

    def test_supported_source_file_suffixes(self):
        """Test adding a supported filetype, of any case, is accepted."""
        ui = self._create_ui()
        accepted_extensions = VHDL_EXTENSIONS + VERILOG_EXTENSIONS
        allowable_extensions = [ext for ext in accepted_extensions]
        allowable_extensions.extend([ext.upper() for ext in accepted_extensions])
        allowable_extensions.append(VHDL_EXTENSIONS[0][0] + VHDL_EXTENSIONS[0][1].upper() +
                                    VHDL_EXTENSIONS[0][2:])  # mixed case
        for idx, ext in enumerate(allowable_extensions):
            fptr = self._create_temp_file(idx, ext)
            ui.add_source_files(fptr.name, 'lib')
            self._delete_temp_files([fptr])

    def test_unsupported_source_file_suffixes(self):
        """Test adding an unsupported filetype is rejected"""
        ui = self._create_ui()
        bogus_ext = '.docx'  # obviously not an HDL file
        files = self._create_temp_files(1, bogus_ext)
        self.assertRaises(RuntimeError, ui.add_source_files, files[0].name, 'lib')
        self._delete_temp_files(files)

    def test_can_add_non_ascii_encoded_files(self):
        ui = self._create_ui()
        lib = ui.library("lib")
        lib.add_source_files(join(dirname(__file__), 'test_ui_encoding.vhd'))
        lib.entity("encoding")  # Fill raise exception of not found

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
        try:
            ui.main()
        except SystemExit as exc:
            if retval is True:
                self.assertEqual(exc.code, 0)
            else:
                self.assertEqual(exc.code, 1)

        pre_config.assert_has_calls([call()])

    def test_entity_has_pre_config(self):
        for retval in (True, False, None):
            self._test_pre_config_helper(retval)

    def test_test_has_pre_config(self):
        self._test_pre_config_helper(True, test_not_entity=False)


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
