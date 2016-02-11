# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import


"""
Verilog preprocessing
"""

from __future__ import print_function
from vunit.parsing.tokenizer import Tokenizer, Token
from vunit.parsing.verilog.tokens import *


class VerilogTokenizer(object):
    """
    A Verilog tokenizer
    """

    def __init__(self, create_locations=True):
        self._tokenizer = Tokenizer()
        self._create_locations = create_locations

        def slice_value(token, start=None, end=None):
            return Token(token.kind, token.value[start:end], token.location)

        def remove_value(token):
            return Token(token.kind, '', token.location)

        def ignore_value(token):  # pylint: disable=unused-argument
            return None

        def add(kind, regex, func=None):
            self._tokenizer.add(kind, regex, func)

        def replace_keywords(token):
            if token.value in KEYWORDS:
                return Token(KEYWORDS[token.value], '', token.location)
            else:
                return token

        add(PREPROCESSOR,
            r"`[a-zA-Z][a-zA-Z0-9_]*",
            lambda token: slice_value(token, start=1))

        add(STRING,
            r'(?<!\\)"(.*?)(?<!\\)"',
            lambda token: slice_value(token, start=1, end=-1))

        add(COMMENT,
            r'//.*$',
            lambda token: slice_value(token, start=2))

        add(IDENTIFIER,
            r"[a-zA-Z_][a-zA-Z0-9_]*",
            replace_keywords)

        add(ESCAPED_NEWLINE,
            r"\\\n",
            ignore_value)

        add(NEWLINE,
            r"\n",
            remove_value)

        add(WHITESPACE,
            r"\s +")

        add(MULTI_COMMENT,
            r"/\*(.|\n)*?\*/",
            lambda token: slice_value(token, start=2, end=-2))

        add(DOUBLE_COLON,
            r"::",
            remove_value)

        add(SEMI_COLON,
            r";",
            remove_value)

        add(HASH,
            r"\#",
            remove_value)

        add(EQUAL,
            r"=",
            remove_value)

        add(LPAR,
            r"\(",
            remove_value)

        add(RPAR,
            r"\)",
            remove_value)

        add(COMMA,
            r",",
            remove_value)

        add(OTHER,
            r".+?")

        self._tokenizer.finalize()

    def tokenize(self, code, file_name=None, previous_location=None):
        """
        Tokenize Verilog code to be preprocessed
        """

        return self._tokenizer.tokenize(code=code,
                                        file_name=file_name,
                                        previous_location=previous_location,
                                        create_locations=self._create_locations)
