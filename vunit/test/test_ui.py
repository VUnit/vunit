# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from string import Template
from tempfile import NamedTemporaryFile
from os.path import join, dirname, basename, exists
from os import remove
from re import compile, MULTILINE
from vunit.ui import VUnit
from vunit.check_preprocessor import CheckPreprocessor

class TestPreprocessor:
    def run(self, code, file_name):
        return '-- check_relation(a = b);\n' + code

class VUnitfier:
    def __init__(self):
        self._reportPattern = compile(r'^(?P<indent>\s*)report\s*(?P<note>"[^"]*")\s*;', MULTILINE)

    def run(self, code, file_name):
        return self._reportPattern.sub(r'\g<indent>log(\g<note>); -- VUnitfier preprocessor: Report turned off, keeping original code.', code)

class ParentalControl:
    def __init__(self):
        self._fWordPattern = compile(r'f..k')

    def run(self, code, file_name):
        return self._fWordPattern.sub(r'[BEEP]', code)

class TestUi(unittest.TestCase):
    def setUp(self):
        self._output_path = join(dirname(__file__), 'ui_out')
        self.maxDiff = None
        self._source = Template("""
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

    def tearDown(self):
        pass

    def _create_ui(self):
        ui = VUnit(output_path = self._output_path)
        ui.add_library('lib')

        return ui

    def _create_temp_files(self, n):
        f = [None] * n
        for i in range(n):
            with NamedTemporaryFile(mode = 'w', suffix='.vhd', delete = False) as f[i]:
                f[i].write(self._source.substitute(entity = 'foo%d' % i))

        return f

    def _delete_temp_files(self, files):
        for f in files:
            remove(f.name)

    def test_global_custom_preprocessors_should_be_applied_in_the_order_they_are_added(self):
        ui = self._create_ui()
        ui.add_preprocessor(VUnitfier())
        ui.add_preprocessor(ParentalControl())

        f = self._create_temp_files(1)
        ui.add_source_files(f[0].name, 'lib')

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
        with open(join(ui._preprocessed_path, 'lib', basename(f[0].name))) as g:
            self.assertEqual(g.read(), pp_source.substitute(entity='foo0', file=basename(f[0].name)))

        self._delete_temp_files(f)

    def test_global_check_and_location_preprocessors_should_be_applied_after_global_custom_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        f = self._create_temp_files(1)
        ui.add_source_files(f[0].name, 'lib')

        pp_source = Template("""-- check_relation(a = b, line_num => 1, file_name => "$file", auto_msg => "Relation a = b failed! Left is " & to_string(a) & ". Right is " & to_string(b) & ".");

library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World", line_num => 11, file_name => "$file");
    check_relation(1 /= 2, line_num => 12, file_name => "$file", auto_msg => "Relation 1 /= 2 failed! Left is " & to_string(1) & ". Right is " & to_string(2) & ".");
    report "Here I am!";
end architecture;
""")
        with open(join(ui._preprocessed_path, 'lib', basename(f[0].name))) as g:
            self.assertEqual(g.read(), pp_source.substitute(entity='foo0', file=basename(f[0].name)))

        self._delete_temp_files(f)


    def test_locally_specified_preprocessors_should_be_used_instead_of_any_globally_defined_preprocessors(self):
        ui = self._create_ui()
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        f = self._create_temp_files(2)

        ui.add_source_files(f[0].name, 'lib', [])
        ui.add_source_files(f[1].name, 'lib', [VUnitfier()])

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
        self.assertFalse(exists(join(ui._preprocessed_path, 'lib', basename(f[0].name))))
        with open(join(ui._preprocessed_path, 'lib', basename(f[1].name))) as h:
            self.assertEqual(h.read(), pp_source.substitute(entity='foo1', report='log("Here I am!"); -- VUnitfier preprocessor: Report turned off, keeping original code.'))

        self._delete_temp_files(f)
