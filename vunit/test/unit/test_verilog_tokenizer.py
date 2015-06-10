# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the Verilog tokenizer
"""

from unittest import TestCase
from vunit.parsing.tokenizer import Token
from vunit.parsing.verilog.tokenizer import tokenize
import vunit.parsing.verilog.tokenizer as tokenizer


class TestVerilogTokenizer(TestCase):
    """
    Test of the Verilog tokenizer
    """

    def test_tokenizes_define(self):
        self.assertEqual(list(tokenize("`define name")),
                         [Token(tokenizer.PREPROCESSOR, value="define"),
                          Token(tokenizer.WHITESPACE, value=""),
                          Token(tokenizer.IDENTIFIER, value="name")])

    def test_tokenizes_string_literal(self):
        self.assertEqual(list(tokenize('"hello"')),
                         [Token(tokenizer.STRING, value='hello')])

        self.assertEqual(list(tokenize('"hel""lo"')),
                         [Token(tokenizer.STRING, value='hel'),
                          Token(tokenizer.STRING, value='lo')])

        self.assertEqual(list(tokenize(r'"h\"ello"')),
                         [Token(tokenizer.STRING, value=r'h\"ello')])

        self.assertEqual(list(tokenize(r'"h\"ello"')),
                         [Token(tokenizer.STRING, value=r'h\"ello')])

        self.assertEqual(list(tokenize(r'"\"ello"')),
                         [Token(tokenizer.STRING, value=r'\"ello')])

        self.assertEqual(list(tokenize(r'"\"\""')),
                         [Token(tokenizer.STRING, value=r'\"\"')])

    def test_tokenizes_single_line_comment(self):
        self.assertEqual(list(tokenize("// asd")),
                         [Token(tokenizer.COMMENT, value=" asd")])

        self.assertEqual(list(tokenize("asd// asd")),
                         [Token(tokenizer.IDENTIFIER, value="asd"),
                          Token(tokenizer.COMMENT, value=" asd")])

        self.assertEqual(list(tokenize("asd// asd //")),
                         [Token(tokenizer.IDENTIFIER, value="asd"),
                          Token(tokenizer.COMMENT, value=" asd //")])

    def test_tokenizes_multi_line_comment(self):
        self.assertEqual(list(tokenize("/* asd */")),
                         [Token(tokenizer.MULTI_COMMENT, value=" asd ")])

        self.assertEqual(list(tokenize("/* /* asd */")),
                         [Token(tokenizer.MULTI_COMMENT, value=" /* asd ")])

        self.assertEqual(list(tokenize("/* /* asd */")),
                         [Token(tokenizer.MULTI_COMMENT, value=" /* asd ")])

        self.assertEqual(list(tokenize("/* 1 \n 2 */")),
                         [Token(tokenizer.MULTI_COMMENT, value=" 1 \n 2 ")])

        self.assertEqual(list(tokenize("/* 1 \r\n 2 */")),
                         [Token(tokenizer.MULTI_COMMENT, value=" 1 \r\n 2 ")])

    def test_tokenizes_semi_colon(self):
        self.assertEqual(list(tokenize("asd;")),
                         [Token(tokenizer.IDENTIFIER, value="asd"),
                          Token(tokenizer.SEMI_COLON, value='')])

    def test_tokenizes_newline(self):
        self.assertEqual(list(tokenize("asd\n")),
                         [Token(tokenizer.IDENTIFIER, value="asd"),
                          Token(tokenizer.NEWLINE, value='')])

    def test_tokenizes_comma(self):
        self.assertEqual(list(tokenize(",")),
                         [Token(tokenizer.COMMA, value='')])

    def test_tokenizes_parenthesis(self):
        self.assertEqual(list(tokenize("()")),
                         [Token(tokenizer.LPAR, value=''),
                          Token(tokenizer.RPAR, value='')])

    def test_tokenizes_hash(self):
        self.assertEqual(list(tokenize("#")),
                         [Token(tokenizer.HASH, value='')])

    def test_tokenizes_equal(self):
        self.assertEqual(list(tokenize("=")),
                         [Token(tokenizer.EQUAL, value='')])

    def test_escaped_newline_ignored(self):
        self.assertEqual(list(tokenize("a\\\nb")),
                         [Token(tokenizer.IDENTIFIER, value='a'),
                          Token(tokenizer.IDENTIFIER, value='b')])

    def test_tokenizes_keywords(self):
        self.assertEqual(list(tokenize("module")),
                         [Token(tokenizer.MODULE, value='')])
        self.assertEqual(list(tokenize("endmodule")),
                         [Token(tokenizer.ENDMODULE, value='')])
        self.assertEqual(list(tokenize("package")),
                         [Token(tokenizer.PACKAGE, value='')])
        self.assertEqual(list(tokenize("endpackage")),
                         [Token(tokenizer.ENDPACKAGE, value='')])
        self.assertEqual(list(tokenize("parameter")),
                         [Token(tokenizer.PARAMETER, value='')])
        self.assertEqual(list(tokenize("import")),
                         [Token(tokenizer.IMPORT, value='')])
