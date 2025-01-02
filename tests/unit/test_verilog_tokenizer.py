# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Test of the Verilog tokenizer
"""

from unittest import TestCase
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.tokens import (
    COMMA,
    COMMENT,
    ENDMODULE,
    ENDPACKAGE,
    EQUAL,
    HASH,
    IDENTIFIER,
    IMPORT,
    LPAR,
    MODULE,
    MULTI_COMMENT,
    NEWLINE,
    PACKAGE,
    PARAMETER,
    PREPROCESSOR,
    RPAR,
    SEMI_COLON,
    STRING,
    WHITESPACE,
)


class TestVerilogTokenizer(TestCase):
    """
    Test of the Verilog tokenizer
    """

    def test_tokenizes_define(self):
        self.check(
            "`define name",
            [
                PREPROCESSOR(value="define"),
                WHITESPACE(value=" "),
                IDENTIFIER(value="name"),
            ],
        )

    def test_newline_is_not_whitespace(self):
        self.check(
            " \n  \n\n",
            [
                WHITESPACE(value=" "),
                NEWLINE(),
                WHITESPACE(value="  "),
                NEWLINE(),
                NEWLINE(),
            ],
        )

    def test_tokenizes_string_literal(self):
        self.check('"hello"', [STRING(value="hello")])

        self.check('"hel""lo"', [STRING(value="hel"), STRING(value="lo")])

        self.check(r'"h\"ello"', [STRING(value='h"ello')])

        self.check(r'"h\"ello"', [STRING(value='h"ello')])

        self.check(r'"\"ello"', [STRING(value='"ello')])

        self.check(r'"\"\""', [STRING(value='""')])

        self.check(
            r'''"hi
there"''',
            [STRING(value="hi\nthere")],
        )

        self.check(
            r'''"hi\
there"''',
            [STRING(value="hithere")],
        )

    def test_tokenizes_single_line_comment(self):
        self.check("// asd", [COMMENT(value=" asd")])

        self.check("asd// asd", [IDENTIFIER(value="asd"), COMMENT(value=" asd")])

        self.check("asd// asd //", [IDENTIFIER(value="asd"), COMMENT(value=" asd //")])

    def test_tokenizes_multi_line_comment(self):
        self.check("/* asd */", [MULTI_COMMENT(value=" asd ")])

        self.check("/* /* asd */", [MULTI_COMMENT(value=" /* asd ")])

        self.check("/* /* asd */", [MULTI_COMMENT(value=" /* asd ")])

        self.check("/* 1 \n 2 */", [MULTI_COMMENT(value=" 1 \n 2 ")])

        self.check("/* 1 \r\n 2 */", [MULTI_COMMENT(value=" 1 \r\n 2 ")])

    def test_tokenizes_semi_colon(self):
        self.check("asd;", [IDENTIFIER(value="asd"), SEMI_COLON(value="")])

    def test_tokenizes_newline(self):
        self.check("asd\n", [IDENTIFIER(value="asd"), NEWLINE(value="")])

    def test_tokenizes_comma(self):
        self.check(",", [COMMA(value="")])

    def test_tokenizes_parenthesis(self):
        self.check("()", [LPAR(value=""), RPAR(value="")])

    def test_tokenizes_hash(self):
        self.check("#", [HASH(value="")])

    def test_tokenizes_equal(self):
        self.check("=", [EQUAL(value="")])

    def test_escaped_newline_ignored(self):
        self.check("a\\\nb", [IDENTIFIER(value="a"), IDENTIFIER(value="b")])

    def test_tokenizes_keywords(self):
        self.check("module", [MODULE(value="module")])
        self.check("endmodule", [ENDMODULE(value="endmodule")])
        self.check("package", [PACKAGE(value="package")])
        self.check("endpackage", [ENDPACKAGE(value="endpackage")])
        self.check("parameter", [PARAMETER(value="parameter")])
        self.check("import", [IMPORT(value="import")])

    def test_has_location_information(self):
        self.check(
            "`define foo",
            [
                PREPROCESSOR(value="define", location=(("fn.v", (0, 6)), None)),
                WHITESPACE(value=" ", location=(("fn.v", (7, 7)), None)),
                IDENTIFIER(value="foo", location=(("fn.v", (8, 10)), None)),
            ],
            strip_loc=False,
        )

    def setUp(self):
        self.tokenizer = VerilogTokenizer()

    def check(self, code, tokens, strip_loc=True):
        """
        Helper method to test tokenizer
        Tokenize code and check that it matches tokens
        optionally strip location information in comparison
        """

        def preprocess(tokens):  # pylint: disable=missing-docstring
            if strip_loc:
                return [token.kind(token.value, None) for token in tokens]

            return tokens

        self.assertEqual(preprocess(list(self.tokenizer.tokenize(code, "fn.v"))), tokens)
