# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Test of the Verilog tokenizer
"""

from unittest import TestCase
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.tokens import *


class TestVerilogTokenizer(TestCase):
    """
    Test of the Verilog tokenizer
    """

    def test_tokenizes_define(self):
        self.check("`define name",
                   [PREPROCESSOR(value="define"),
                    WHITESPACE(value=" "),
                    IDENTIFIER(value="name")])

    def test_tokenizes_string_literal(self):
        self.check('"hello"',
                   [STRING(value='hello')])

        self.check('"hel""lo"',
                   [STRING(value='hel'),
                    STRING(value='lo')])

        self.check(r'"h\"ello"',
                   [STRING(value=r'h\"ello')])

        self.check(r'"h\"ello"',
                   [STRING(value=r'h\"ello')])

        self.check(r'"\"ello"',
                   [STRING(value=r'\"ello')])

        self.check(r'"\"\""',
                   [STRING(value=r'\"\"')])

    def test_tokenizes_single_line_comment(self):
        self.check("// asd",
                   [COMMENT(value=" asd")])

        self.check("asd// asd",
                   [IDENTIFIER(value="asd"),
                    COMMENT(value=" asd")])

        self.check("asd// asd //",
                   [IDENTIFIER(value="asd"),
                    COMMENT(value=" asd //")])

    def test_tokenizes_multi_line_comment(self):
        self.check("/* asd */",
                   [MULTI_COMMENT(value=" asd ")])

        self.check("/* /* asd */",
                   [MULTI_COMMENT(value=" /* asd ")])

        self.check("/* /* asd */",
                   [MULTI_COMMENT(value=" /* asd ")])

        self.check("/* 1 \n 2 */",
                   [MULTI_COMMENT(value=" 1 \n 2 ")])

        self.check("/* 1 \r\n 2 */",
                   [MULTI_COMMENT(value=" 1 \r\n 2 ")])

    def test_tokenizes_semi_colon(self):
        self.check("asd;",
                   [IDENTIFIER(value="asd"),
                    SEMI_COLON(value='')])

    def test_tokenizes_newline(self):
        self.check("asd\n",
                   [IDENTIFIER(value="asd"),
                    NEWLINE(value='')])

    def test_tokenizes_comma(self):
        self.check(",",
                   [COMMA(value='')])

    def test_tokenizes_parenthesis(self):
        self.check("()",
                   [LPAR(value=''),
                    RPAR(value='')])

    def test_tokenizes_hash(self):
        self.check("#",
                   [HASH(value='')])

    def test_tokenizes_equal(self):
        self.check("=",
                   [EQUAL(value='')])

    def test_escaped_newline_ignored(self):
        self.check("a\\\nb",
                   [IDENTIFIER(value='a'),
                    IDENTIFIER(value='b')])

    def test_tokenizes_keywords(self):
        self.check("module",
                   [MODULE(value='')])
        self.check("endmodule",
                   [ENDMODULE(value='')])
        self.check("package",
                   [PACKAGE(value='')])
        self.check("endpackage",
                   [ENDPACKAGE(value='')])
        self.check("parameter",
                   [PARAMETER(value='')])
        self.check("import",
                   [IMPORT(value='')])

    def test_has_location_information(self):
        self.check("`define foo", [
            PREPROCESSOR(value="define", location=(("fn.v", (0, 6)), None)),
            WHITESPACE(value=" ", location=(("fn.v", (7, 7)), None)),
            IDENTIFIER(value="foo", location=(("fn.v", (8, 10)), None)),
        ], strip_loc=False)

    def setUp(self):
        self.tokenizer = VerilogTokenizer()

    def check(self, code, tokens, strip_loc=True):
        """
        Helper method to test tokenizer
        Tokenize code and check that it matches tokens
        optionally strip location information in comparison
        """

        def preprocess(tokens):
            if strip_loc:
                return [token.kind(token.value, None) for token in tokens]
            else:
                return tokens

        self.assertEqual(preprocess(list(self.tokenizer.tokenize(code, "fn.v"))),
                         tokens)
