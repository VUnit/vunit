# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the location preprocessor
"""


import unittest
from vunit.location_preprocessor import LocationPreprocessor


class TestLocationPreprocessor(unittest.TestCase):
    """
    Test the location preprocessor
    """

    def setUp(self):
        self._location_preprocessor = LocationPreprocessor()
        self._location_preprocessor.add_subprogram('sub_prog')

    def _verify_result(self, code, expected_result):
        """
        Assert that the code after preprocessing is equal to the expected_result
        """
        result = self._location_preprocessor.run(code, 'foo.vhd')
        self.assertEqual(result, expected_result)

    def test_that_procedure_calls_are_found(self):
        code = """
sub_prog("1");
 sub_prog("2");
 sub_prog ("3");
 sub_prog (" 4 ");
 sub_prog (" 5 ") ;
sub_prog("6",
         "7");
 sub_prog;
"""
        expected_result = """
sub_prog("1", line_num => 2, file_name => "foo.vhd");
 sub_prog("2", line_num => 3, file_name => "foo.vhd");
 sub_prog ("3", line_num => 4, file_name => "foo.vhd");
 sub_prog (" 4 ", line_num => 5, file_name => "foo.vhd");
 sub_prog (" 5 ", line_num => 6, file_name => "foo.vhd") ;
sub_prog("6",
         "7", line_num => 7, file_name => "foo.vhd");
 sub_prog(line_num => 9, file_name => "foo.vhd");
"""
        self._verify_result(code, expected_result)

    def test_that_function_calls_are_found(self):
        code = """
a:=sub_prog("1");
 b :=sub_prog("2");
 c := sub_prog ("3");
 d  :=  sub_prog (" 4 ");
 e<=sub_prog (" 5 ") ;
f  <=  sub_prog;
g := h + sub_prog + 3; -- DOESN'T SUPPORT FUNCTION CALLS WITHOUT PARAMETERS NOT FOLLOWED BY SEMICOLON
i := j * (sub_prog(1, 2) + 17) + 8;
k := l * (sub_prog(1,
                   2) + 17) + 8;
"""
        expected_result = """
a:=sub_prog("1", line_num => 2, file_name => "foo.vhd");
 b :=sub_prog("2", line_num => 3, file_name => "foo.vhd");
 c := sub_prog ("3", line_num => 4, file_name => "foo.vhd");
 d  :=  sub_prog (" 4 ", line_num => 5, file_name => "foo.vhd");
 e<=sub_prog (" 5 ", line_num => 6, file_name => "foo.vhd") ;
f  <=  sub_prog(line_num => 7, file_name => "foo.vhd");
g := h + sub_prog + 3; -- DOESN'T SUPPORT FUNCTION CALLS WITHOUT PARAMETERS NOT FOLLOWED BY SEMICOLON
i := j * (sub_prog(1, 2, line_num => 9, file_name => "foo.vhd") + 17) + 8;
k := l * (sub_prog(1,
                   2, line_num => 10, file_name => "foo.vhd") + 17) + 8;
"""
        self._verify_result(code, expected_result)

    def test_that_similar_sub_program_names_are_ignored(self):
        code = """
another_sub_prog("6");
sub_prog_2;
"""
        expected_result = """
another_sub_prog("6");
sub_prog_2;
"""
        self._verify_result(code, expected_result)

    def test_that_sub_program_declarations_are_ignored(self):
        code = """
procedure sub_prog(foo1);
 function  sub_prog (foo3) ;
"""
        expected_result = """
procedure sub_prog(foo1);
 function  sub_prog (foo3) ;
"""
        self._verify_result(code, expected_result)

    def test_that_sub_program_definitions_are_ignored(self):
        code = """
procedure sub_prog(foo4) is
begin
    null;
end;
function sub_prog(foo4) return boolean is
begin
    return true;
end;
"""
        expected_result = """
procedure sub_prog(foo4) is
begin
    null;
end;
function sub_prog(foo4) return boolean is
begin
    return true;
end;
"""
        self._verify_result(code, expected_result)

    def test_that_already_located_calls_are_left_untouched(self):
        code = """
procedure sub_prog(foo4) is
begin
    sub_prog("foo", line_num=> 17);
end;
procedure sub_prog(foo4) is
begin
    sub_prog("foo",
             file_name=>"foo.vhd");
end;
procedure sub_prog(foo4) is
begin
    sub_prog("foo", line_num => 17, file_name => "foo.vhd");
end;
"""
        expected_result = """
procedure sub_prog(foo4) is
begin
    sub_prog("foo", line_num=> 17, file_name => "foo.vhd");
end;
procedure sub_prog(foo4) is
begin
    sub_prog("foo",
             file_name=>"foo.vhd", line_num => 8);
end;
procedure sub_prog(foo4) is
begin
    sub_prog("foo", line_num => 17, file_name => "foo.vhd");
end;
"""
        self._verify_result(code, expected_result)

    def test_that_asserts_with_severity_level_are_not_affected_despite_name_conflict_with_log_functions(self):
        code = """
assert False report "Failed" severity warning;
assert False report "Failed" severity error;
assert False report "Failed" severity failure;
"""
        expected_result = """
assert False report "Failed" severity warning;
assert False report "Failed" severity error;
assert False report "Failed" severity failure;
"""
        self._verify_result(code, expected_result)
