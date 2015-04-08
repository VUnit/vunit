# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the check preprocessor
"""


import unittest
from vunit.check_preprocessor import CheckPreprocessor


class TestCheckPreprocessor(unittest.TestCase):
    """
    Test the check preprocessor
    """

    def setUp(self):
        self._check_preprocessor = CheckPreprocessor()

    def _verify_result(self, code, expected_result):
        """
        Assert that the code after preprocessing is equal to the expected_result
        """
        result = self._check_preprocessor.run(code, 'foo.vhd')
        self.assertEqual(result, expected_result)

    def test_that_only_relation_checks_are_preprocessed_so_that_parsing_is_simplified(self):
        code = """
check_relation(a /= b);
check(a /= b or c); -- Same as (a /= b) or c. Not a relation
"""
        expected_result = """
check_relation(a /= b, auto_msg => %s);
check(a /= b or c); -- Same as (a /= b) or c. Not a relation
""" % make_auto_msg('a', '/=', 'b')

        self._verify_result(code, expected_result)

    def test_that_generated_message_is_combined_with_a_custom_message(self):
        code = """
check_relation(age("John") >= 0, "Age must not be negative.");
"""
        expected_result = """
check_relation(age("John") >= 0, "Age must not be negative.", auto_msg => %s);
""" % make_auto_msg('age("John")', '>=', '0')

        self._verify_result(code, expected_result)

    def test_that_the_top_level_relation_is_correctly_identified_as_the_main_relation(self):
        code = """
check_relation(foo(a > b) = c);
check_relation((a > b) = c);
check_relation(a > (b = c));
check_relation(( (a > b))  );"""

        expected_result = """
check_relation(foo(a > b) = c, auto_msg => %s);
check_relation((a > b) = c, auto_msg => %s);
check_relation(a > (b = c), auto_msg => %s);
check_relation(( (a > b))  , auto_msg => %s);""" % (make_auto_msg('foo(a > b)', '=', 'c'),
                                                    make_auto_msg('(a > b)', '=', 'c'),
                                                    make_auto_msg('a', '>', '(b = c)'),
                                                    make_auto_msg('a', '>', 'b'))

        self._verify_result(code, expected_result)

    def test_that_parsing_is_not_fooled_by_strings_containing_characters_relevant_to_parsing(self):
        code = """
check_relation(41 = ascii(')'), "Incorrect ascii for ')'");
check_relation(9 = len("Smile :-)"), "Incorrect length of :-) message");
check_relation(8 = len("Heart => <3"), "Incorrect length of <3 message");
check_relation(a = integer'(9), "This wasn't expected");
check_relation(a = std_logic'('1'), "This wasn't expected");
check_relation(a = func('(','x'), "This wasn't expected");
check_relation(a = std_logic'('1'+'1'), "This wasn't expected");
check_relation(39 = ascii('''), "Incorrect ascii for '''");
check_relation(byte'high = 7);"""

        expected_result = """
check_relation(41 = ascii(')'), "Incorrect ascii for ')'", auto_msg => %s);
check_relation(9 = len("Smile :-)"), "Incorrect length of :-) message", auto_msg => %s);
check_relation(8 = len("Heart => <3"), "Incorrect length of <3 message", auto_msg => %s);
check_relation(a = integer'(9), "This wasn't expected", auto_msg => %s);
check_relation(a = std_logic'('1'), "This wasn't expected", auto_msg => %s);
check_relation(a = func('(','x'), "This wasn't expected", auto_msg => %s);
check_relation(a = std_logic'('1'+'1'), "This wasn't expected", auto_msg => %s);
check_relation(39 = ascii('''), "Incorrect ascii for '''", auto_msg => %s);
check_relation(byte'high = 7, auto_msg => %s);""" % (make_auto_msg('41', '=', "ascii(')')"),
                                                     make_auto_msg('9', '=', 'len("Smile :-)")'),
                                                     make_auto_msg('8', '=', 'len("Heart => <3")'),
                                                     make_auto_msg('a', '=', "integer'(9)"),
                                                     make_auto_msg('a', '=', "std_logic'('1')"),
                                                     make_auto_msg('a', '=', "func('(','x')"),
                                                     make_auto_msg('a', '=', "std_logic'('1'+'1')"),
                                                     make_auto_msg('39', '=', "ascii(''')"),
                                                     make_auto_msg("byte'high", '=', '7'))

        self._verify_result(code, expected_result)

    def test_that_parsing_is_not_fooled_by_embedded_comments(self):
        code = """
check_relation(42 = -- Meaning of life :-)
               hex(66));
check_relation(42 = /* Meaning of
                       life :-) */
               hex(66));
"""
        expected_result = """
check_relation(42 = -- Meaning of life :-)
               hex(66), auto_msg => %s);
check_relation(42 = /* Meaning of
                       life :-) */
               hex(66), auto_msg => %s);
""" % (make_auto_msg('42', '=', 'hex(66)'), make_auto_msg('42', '=', 'hex(66)'))

        self._verify_result(code, expected_result)

    def test_that_a_call_without_a_relational_operator_raises_an_error(self):
        code = """
check_relation(a + b - c);
"""
        self.assertRaises(SyntaxError, self._check_preprocessor.run, code, 'foo.vhd')

    def test_that_multiple_parameters_can_be_given(self):
        code = """
check_relation(a = b, level => warning);
check_relation(my_checker, a = b);
check_relation(msg => "Error!", expr => a('<') = b);"""

        expected_result = """
check_relation(a = b, level => warning, auto_msg => %s);
check_relation(my_checker, a = b, auto_msg => %s);
check_relation(msg => "Error!", expr => a('<') = b, auto_msg => %s);""" % (make_auto_msg('a', '=', 'b'),
                                                                           make_auto_msg('a', '=', 'b'),
                                                                           make_auto_msg("a('<')", '=', 'b'))

        self._verify_result(code, expected_result)

    def test_that_all_vhdl_2008_relational_operators_are_recognized(self):
        code = """
check_relation(a = b);
check_relation(a /= b);
check_relation(a < b);
check_relation(a <= b);
check_relation(a > b);
check_relation(a >= b);
check_relation(a ?= b);
check_relation(a ?/= b);
check_relation(a ?< b);
check_relation(a ?<= b);
check_relation(a ?> b);
check_relation(a ?>= b);"""

        expected_result = """
check_relation(a = b, auto_msg => %s);
check_relation(a /= b, auto_msg => %s);
check_relation(a < b, auto_msg => %s);
check_relation(a <= b, auto_msg => %s);
check_relation(a > b, auto_msg => %s);
check_relation(a >= b, auto_msg => %s);
check_relation(a ?= b, auto_msg => %s);
check_relation(a ?/= b, auto_msg => %s);
check_relation(a ?< b, auto_msg => %s);
check_relation(a ?<= b, auto_msg => %s);
check_relation(a ?> b, auto_msg => %s);
check_relation(a ?>= b, auto_msg => %s);""" % (make_auto_msg("a", '=', 'b'),
                                               make_auto_msg("a", '/=', 'b'),
                                               make_auto_msg("a", '<', 'b'),
                                               make_auto_msg("a", '<=', 'b'),
                                               make_auto_msg("a", '>', 'b'),
                                               make_auto_msg("a", '>=', 'b'),
                                               make_auto_msg("a", '?=', 'b'),
                                               make_auto_msg("a", '?/=', 'b'),
                                               make_auto_msg("a", '?<', 'b'),
                                               make_auto_msg("a", '?<=', 'b'),
                                               make_auto_msg("a", '?>', 'b'),
                                               make_auto_msg("a", '?>=', 'b'))
        self._verify_result(code, expected_result)


def make_auto_msg(left, relation, right):
    return ('"Relation %s %s %s failed! Left is " & to_string(%s) & ". Right is " & to_string(%s) & "."' %
            (left.replace('"', '""'),
             relation,
             right.replace('"', '""'),
             left,
             right))
