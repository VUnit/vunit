# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import


"""
Verilog preprocessing
"""

from vunit.parsing.tokenizer import Tokenizer, Token
from vunit.parsing.verilog.tokens import (
    COLON,
    COMMA,
    COMMENT,
    EQUAL,
    ESCAPED_NEWLINE,
    DOUBLE_COLON,
    HASH,
    IDENTIFIER,
    KEYWORDS,
    LBRACE,
    LBRACKET,
    LPAR,
    MULTI_COMMENT,
    NEWLINE,
    OTHER,
    PREPROCESSOR,
    RBRACE,
    RBRACKET,
    RPAR,
    SEMI_COLON,
    STRING,
    WHITESPACE,
)


class VerilogTokenizer(object):
    """
    A Verilog tokenizer
    """

    def __init__(self, create_locations=True):
        self._tokenizer = Tokenizer()
        self._create_locations = create_locations

        def slice_value(token, start=None, end=None):
            return Token(token.kind, token.value[start:end], token.location)

        def str_value(token):
            return Token(
                token.kind,
                token.value[1:-1].replace("\\\n", "").replace('\\"', '"'),
                token.location,
            )

        def remove_value(token):
            return Token(token.kind, "", token.location)

        def ignore_value(token):  # pylint: disable=unused-argument
            pass

        def add(kind, regex, func=None):
            self._tokenizer.add(kind, regex, func)

        def replace_keywords(token):  # pylint: disable=missing-docstring
            if token.value in KEYWORDS:
                return Token(KEYWORDS[token.value], token.value, token.location)

            return token

        add(
            PREPROCESSOR,
            r"`[a-zA-Z][a-zA-Z0-9_]*",
            lambda token: slice_value(token, start=1),
        )

        add(STRING, r'(?<!\\)"((.|\n)*?)(?<!\\)"', str_value)

        add(COMMENT, r"//.*$", lambda token: slice_value(token, start=2))

        add(IDENTIFIER, r"[a-zA-Z_][a-zA-Z0-9_]*", replace_keywords)

        add(ESCAPED_NEWLINE, r"\\\n", ignore_value)

        add(NEWLINE, r"\n", remove_value)

        add(WHITESPACE, r"[ \t]+")

        add(
            MULTI_COMMENT,
            r"/\*(.|\n)*?\*/",
            lambda token: slice_value(token, start=2, end=-2),
        )

        add(DOUBLE_COLON, r"::", remove_value)

        add(COLON, r":", remove_value)

        add(SEMI_COLON, r";", remove_value)

        add(HASH, r"\#", remove_value)

        add(EQUAL, r"=", remove_value)

        add(LPAR, r"\(", remove_value)

        add(RPAR, r"\)", remove_value)

        add(LBRACKET, r"\[", remove_value)

        add(RBRACKET, r"\]", remove_value)

        add(LBRACE, r"{", remove_value)

        add(RBRACE, r"}", remove_value)

        add(COMMA, r",", remove_value)

        add(OTHER, r".+?")

        self._tokenizer.finalize()

    def tokenize(self, code, file_name=None, previous_location=None):
        """
        Tokenize Verilog code to be preprocessed
        """

        return self._tokenizer.tokenize(
            code=code,
            file_name=file_name,
            previous_location=previous_location,
            create_locations=self._create_locations,
        )
