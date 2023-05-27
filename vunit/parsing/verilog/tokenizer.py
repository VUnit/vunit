# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import


"""
Verilog preprocessing
"""

from typing import Callable, Optional
from vunit.parsing.tokenizer import Location, Tokenizer, Token
from vunit.parsing.verilog.tokens import KEYWORDS, KeywordKind, TokenKind


class VerilogTokenizer:
    """
    A Verilog tokenizer
    """

    _tokenizer: Tokenizer
    _create_locations: bool

    def __init__(self, create_locations: bool = True):
        self._tokenizer = Tokenizer()
        self._create_locations = create_locations

        def slice_value(token: Token, start: Optional[int] = None, end: Optional[int] = None):
            return Token(token.kind, token.value[start:end], token.location)

        def str_value(token: Token) -> Token:
            return Token(
                token.kind,
                token.value[1:-1].replace("\\\n", "").replace('\\"', '"'),
                token.location,
            )

        def remove_value(token: Token) -> Token:
            return Token(token.kind, "", token.location)

        def ignore_value(_: Token) -> None:  # pylint: disable=unused-argument
            pass

        def add(kind: TokenKind, regex: str, func: Optional[Callable[[Token], Optional[Token]]] = None):
            self._tokenizer.add(kind, regex, func)

        def replace_keywords(token: Token) -> Token:  # pylint: disable=missing-docstring
            if token.value in KEYWORDS:
                return Token(KeywordKind(token.value), token.value, token.location)

            return token

        add(
            TokenKind.PREPROCESSOR,
            r"`[a-zA-Z][a-zA-Z0-9_]*",
            lambda token: slice_value(token, start=1),
        )

        add(TokenKind.STRING, r'(?<!\\)"((.|\n)*?)(?<!\\)"', str_value)

        add(TokenKind.COMMENT, r"//.*$", lambda token: slice_value(token, start=2))

        add(TokenKind.IDENTIFIER, r"[a-zA-Z_][a-zA-Z0-9_]*", replace_keywords)

        add(TokenKind.ESCAPED_NEWLINE, r"\\\n", ignore_value)

        add(TokenKind.NEWLINE, r"\n", remove_value)

        add(TokenKind.WHITESPACE, r"[ \t]+")

        add(
            TokenKind.MULTI_COMMENT,
            r"/\*(.|\n)*?\*/",
            lambda token: slice_value(token, start=2, end=-2),
        )

        add(TokenKind.DOUBLE_COLON, r"::", remove_value)

        add(TokenKind.COLON, r":", remove_value)

        add(TokenKind.SEMI_COLON, r";", remove_value)

        add(TokenKind.HASH, r"\#", remove_value)

        add(TokenKind.EQUAL, r"=", remove_value)

        add(TokenKind.LPAR, r"\(", remove_value)

        add(TokenKind.RPAR, r"\)", remove_value)

        add(TokenKind.LBRACKET, r"\[", remove_value)

        add(TokenKind.RBRACKET, r"\]", remove_value)

        add(TokenKind.LBRACE, r"{", remove_value)

        add(TokenKind.RBRACE, r"}", remove_value)

        add(TokenKind.COMMA, r",", remove_value)

        add(TokenKind.OTHER, r".+?")

        self._tokenizer.finalize()

    def tokenize(self, code: str, file_name: Optional[str] = None, previous_location: Optional[Location] = None):
        """
        Tokenize Verilog code to be preprocessed
        """

        return self._tokenizer.tokenize(
            code=code,
            file_name=file_name,
            previous_location=previous_location,
            create_locations=self._create_locations,
        )
