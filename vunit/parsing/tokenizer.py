# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
A general tokenizer
"""

from dataclasses import dataclass
import logging
import re
from typing import Callable, Dict, List, Optional, Tuple, Union
from typing_extensions import Self, Literal
from vunit.ostools import read_file, file_exists, simplify_path
from typing_extensions import TypeAlias

from vunit.parsing.verilog.tokens import KeywordKind, TokenKind

Location: TypeAlias = Tuple[Tuple[Optional[str], Tuple[int, int]], Optional["Location"]]


@dataclass(frozen=True)
class Token:
    kind: Union[TokenKind, KeywordKind]
    value: str = ""
    location: Optional[Location] = None


class Tokenizer:
    """
    Maintain a prioritized list of token regex
    """

    _regexs: List[Tuple[str, str]]
    _assoc: Dict[str, Tuple[TokenKind, Optional[Callable[[Token], Optional[Token]]]]]
    _regex: Optional[re.Pattern[str]]

    def __init__(self):
        self._regexs = []
        self._assoc = {}
        self._regex = None

    def add(self, kind: TokenKind, regex: str, func: Optional[Callable[[Token], Optional[Token]]] = None) -> TokenKind:
        """
        Add token type
        """
        key = chr(ord("a") + len(self._regexs))
        self._regexs.append((key, regex))
        self._assoc[key] = (kind, func)
        return kind

    def finalize(self) -> None:
        self._regex = re.compile(
            "|".join(f"(?P<{spec[0]!s}>{spec[1]!s})" for spec in self._regexs),
            re.VERBOSE | re.MULTILINE,
        )

    def tokenize(
        self,
        code: str,
        file_name: Optional[str] = None,
        previous_location: Optional[Location] = None,
        create_locations: bool = False,
    ) -> List[Token]:
        """
        Tokenize the code
        """
        tokens: List[Token] = []
        start = 0

        assert self._regex is not None
        while True:
            match = self._regex.search(code, pos=start)
            if match is None:
                break
            lexpos = (start, match.end() - 1)
            start = match.end()
            assert match.lastgroup is not None
            kind, func = self._assoc[match.lastgroup]
            value = match.group(match.lastgroup)

            if create_locations:
                location = ((file_name, lexpos), previous_location)
            else:
                location = None

            token = Token(kind, value, location)
            if func is not None:
                token = func(token)

            if token is not None:
                tokens.append(token)
        return tokens


class TokenStream:
    """
    Helper class for traversing a stream of tokens
    """

    _tokens: List[Token]
    _idx: int

    def __init__(self, tokens: List[Token]):
        self._tokens = tokens
        self._idx = 0

    def __len__(self):
        return len(self._tokens)

    def __getitem__(self, index: int) -> Token:
        return self._tokens[index]

    @property
    def eof(self) -> bool:
        return not self._idx < len(self._tokens)

    @property
    def idx(self) -> int:
        return self._idx

    @property
    def current(self) -> Token:
        return self._tokens[self._idx]

    def peek(self, offset: int = 0) -> Token:
        return self._tokens[self._idx + offset]

    def skip_while(self, *kinds: TokenKind) -> int:
        """
        Skip forward while token kind is present
        """
        while not self.eof:
            if not any(self._tokens[self._idx].kind == kind for kind in kinds):
                break
            self._idx += 1
        return self._idx

    def skip_until(self, *kinds: TokenKind) -> int:
        """
        Skip forward until token kind is present
        """
        while not self.eof:
            if any(self._tokens[self._idx].kind == kind for kind in kinds):
                break
            self._idx += 1
        return self._idx

    def pop(self) -> Token:
        """
        Return current token and advance stream
        """
        if self.eof:
            raise EOFException()

        self._idx += 1
        return self._tokens[self._idx - 1]

    def expect(self, *kinds: TokenKind) -> Token:
        """
        Expect to pop token with any of kinds
        """
        token = self.pop()
        if token.kind not in kinds:
            expected = str(kinds[0]) if len(kinds) == 1 else f"any of [{', '.join(str(kind) for kind in kinds)}]"
            raise LocationException.error(f"Expected {expected!s} got {token.kind!s}", token.location)
        return token

    def slice(self, start: int, end: int) -> List[Token]:
        return self._tokens[start:end]


def describe_location(location: Optional[Location], first: bool = True) -> str:
    """
    Describe the location as a string
    """
    if location is None:
        return "Unknown location"

    ((file_name, (start, end)), previous) = location

    retval = ""
    if previous is not None:
        retval += describe_location(previous, first=False) + "\n"

    if file_name is None:
        retval += "Unknown Python string"
        return retval

    if not file_exists(file_name):
        retval += f"Unknown location in {file_name!s}"
        return retval

    contents = read_file(file_name)

    if first:
        prefix = "at"
    else:
        prefix = "from"

    count = 0
    for lineno, line in enumerate(contents.splitlines()):
        lstart = count
        lend = lstart + len(line)
        if lstart <= start <= lend:
            retval += f"{prefix!s} {simplify_path(file_name)!s} line {lineno + 1:d}:\n"
            retval += line + "\n"
            retval += (" " * (start - lstart)) + ("~" * (min(lend - 1, end) - start + 1))
            return retval

        count = lend + 1
    return retval


class EOFException(Exception):
    """
    End of file
    """


class LocationException(Exception):
    """
    A an exception to be raised when there is a problem in a location
    """

    @classmethod
    def error(cls, message: str, location: Optional[Location]) -> Self:
        return cls(message, location, "error")

    @classmethod
    def warning(cls, message: str, location: Optional[Location]) -> Self:
        return cls(message, location, "warning")

    @classmethod
    def debug(cls, message: str, location: Optional[Location]) -> Self:
        return cls(message, location, "debug")

    def __init__(self, message: str, location: Optional[Location], severity: Literal["debug", "warning", "error"]):
        super().__init__(self)
        assert severity in ("debug", "warning", "error")
        self._severtity = severity
        self._message = message
        self._location = location

    def log(self, logger: logging.Logger) -> None:
        """
        Log the exception
        """
        if self._severtity == "error":
            method = logger.error
        elif self._severtity == "warning":
            method = logger.warning
        else:
            method = logger.debug

        method(self._message + "\n%s", describe_location(self._location))


def add_previous(location: Optional[Location], previous: Optional[Location]) -> Optional[Location]:
    """
    Add previous location
    """
    if location is None:
        return previous

    current, old_previous = location
    return (current, add_previous(old_previous, previous))


def strip_previous(location: Optional[Location]) -> Optional[Tuple[Optional[str], Tuple[int, int]]]:
    """
    Strip previous location
    """
    if location is None:
        return None
    return location[0]
