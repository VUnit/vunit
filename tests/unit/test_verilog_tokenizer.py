# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Test of the Verilog tokenizer
"""

from typing import List
from unittest import TestCase
from vunit.parsing.tokenizer import Token
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.tokens import TokenKind, KeywordKind


class TestVerilogTokenizer(TestCase):
    """
    Test of the Verilog tokenizer
    """

    def test_tokenizes_define(self):
        self.check(
            "`define name",
            [
                Token(TokenKind.PREPROCESSOR, value="define"),
                Token(TokenKind.WHITESPACE, value=" "),
                Token(TokenKind.IDENTIFIER, value="name"),
            ],
        )

    def test_newline_is_not_whitespace(self):
        self.check(
            " \n  \n\n",
            [
                Token(TokenKind.WHITESPACE, value=" "),
                Token(TokenKind.NEWLINE),
                Token(TokenKind.WHITESPACE, value="  "),
                Token(TokenKind.NEWLINE),
                Token(TokenKind.NEWLINE),
            ],
        )

    def test_tokenizes_string_literal(self):
        self.check('"hello"', [Token(TokenKind.STRING, value="hello")])

        self.check('"hel""lo"', [Token(TokenKind.STRING, value="hel"), Token(TokenKind.STRING, value="lo")])

        self.check(r'"h\"ello"', [Token(TokenKind.STRING, value='h"ello')])

        self.check(r'"h\"ello"', [Token(TokenKind.STRING, value='h"ello')])

        self.check(r'"\"ello"', [Token(TokenKind.STRING, value='"ello')])

        self.check(r'"\"\""', [Token(TokenKind.STRING, value='""')])

        self.check(
            r'''"hi
there"''',
            [Token(TokenKind.STRING, value="hi\nthere")],
        )

        self.check(
            r'''"hi\
there"''',
            [Token(TokenKind.STRING, value="hithere")],
        )

    def test_tokenizes_single_line_comment(self):
        self.check("// asd", [Token(TokenKind.COMMENT, value=" asd")])

        self.check("asd// asd", [Token(TokenKind.IDENTIFIER, value="asd"), Token(TokenKind.COMMENT, value=" asd")])

        self.check(
            "asd// asd //", [Token(TokenKind.IDENTIFIER, value="asd"), Token(TokenKind.COMMENT, value=" asd //")]
        )

    def test_tokenizes_multi_line_comment(self):
        self.check("/* asd */", [Token(TokenKind.MULTI_COMMENT, value=" asd ")])

        self.check("/* /* asd */", [Token(TokenKind.MULTI_COMMENT, value=" /* asd ")])

        self.check("/* /* asd */", [Token(TokenKind.MULTI_COMMENT, value=" /* asd ")])

        self.check("/* 1 \n 2 */", [Token(TokenKind.MULTI_COMMENT, value=" 1 \n 2 ")])

        self.check("/* 1 \r\n 2 */", [Token(TokenKind.MULTI_COMMENT, value=" 1 \r\n 2 ")])

    def test_tokenizes_semi_colon(self):
        self.check("asd;", [Token(TokenKind.IDENTIFIER, value="asd"), Token(TokenKind.SEMI_COLON, value="")])

    def test_tokenizes_newline(self):
        self.check("asd\n", [Token(TokenKind.IDENTIFIER, value="asd"), Token(TokenKind.NEWLINE, value="")])

    def test_tokenizes_comma(self):
        self.check(",", [Token(TokenKind.COMMA, value="")])

    def test_tokenizes_parenthesis(self):
        self.check("()", [Token(TokenKind.LPAR, value=""), Token(TokenKind.RPAR, value="")])

    def test_tokenizes_hash(self):
        self.check("#", [Token(TokenKind.HASH, value="")])

    def test_tokenizes_equal(self):
        self.check("=", [Token(TokenKind.EQUAL, value="")])

    def test_escaped_newline_ignored(self):
        self.check("a\\\nb", [Token(TokenKind.IDENTIFIER, value="a"), Token(TokenKind.IDENTIFIER, value="b")])

    def test_tokenizes_keywords(self):
        self.check("module", [Token(KeywordKind.MODULE, value="module")])
        self.check("endmodule", [Token(KeywordKind.ENDMODULE, value="endmodule")])
        self.check("package", [Token(KeywordKind.PACKAGE, value="package")])
        self.check("endpackage", [Token(KeywordKind.ENDPACKAGE, value="endpackage")])
        self.check("parameter", [Token(KeywordKind.PARAMETER, value="parameter")])
        self.check("import", [Token(KeywordKind.IMPORT, value="import")])

    def test_has_location_information(self):
        self.check(
            "`define foo",
            [
                Token(TokenKind.PREPROCESSOR, value="define", location=(("fn.v", (0, 6)), None)),
                Token(TokenKind.WHITESPACE, value=" ", location=(("fn.v", (7, 7)), None)),
                Token(TokenKind.IDENTIFIER, value="foo", location=(("fn.v", (8, 10)), None)),
            ],
            strip_loc=False,
        )

    def setUp(self):
        self.tokenizer = VerilogTokenizer()

    def check(self, code: str, tokens: List[Token], strip_loc: bool = True):
        """
        Helper method to test tokenizer
        Tokenize code and check that it matches tokens
        optionally strip location information in comparison
        """

        def preprocess(tokens: List[Token]):  # pylint: disable=missing-docstring
            if strip_loc:
                return [Token(token.kind, token.value) for token in tokens]

            return tokens

        self.assertEqual(preprocess(list(self.tokenizer.tokenize(code, "fn.v"))), tokens)
