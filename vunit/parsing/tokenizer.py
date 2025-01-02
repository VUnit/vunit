# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
A general tokenizer
"""

import collections
import re
from vunit.ostools import read_file, file_exists, simplify_path


TokenType = collections.namedtuple("TokenType", ["kind", "value", "location"])


def Token(kind, value="", location=None):  # pylint: disable=invalid-name
    return TokenType(kind, value, location)


class TokenKind:
    pass


def new_token_kind(name: str) -> TokenKind:
    """
    Create a new token kind with nice __repr__
    """

    def new_token(kind, value="", location=None):
        """
        Create new token of kind
        """
        return Token(kind, value, location)

    cls = type(name, (object,), {"__repr__": lambda self: name, "__call__": new_token})
    return cls()


class Tokenizer(object):
    """
    Maintain a prioritized list of token regex
    """

    def __init__(self):
        self._regexs = []
        self._assoc = {}
        self._regex = None

    def add(self, kind, regex, func=None):
        """
        Add token type
        """
        key = chr(ord("a") + len(self._regexs))
        self._regexs.append((key, regex))
        self._assoc[key] = (kind, func)
        return kind

    def finalize(self):
        self._regex = re.compile(
            "|".join(f"(?P<{spec[0]!s}>{spec[1]!s})" for spec in self._regexs),
            re.VERBOSE | re.MULTILINE,
        )

    def tokenize(self, code, file_name=None, previous_location=None, create_locations=False):
        """
        Tokenize the code
        """
        tokens = []
        start = 0
        while True:
            match = self._regex.search(code, pos=start)
            if match is None:
                break
            lexpos = (start, match.end() - 1)
            start = match.end()
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


class TokenStream(object):
    """
    Helper class for traversing a stream of tokens
    """

    def __init__(self, tokens):
        self._tokens = tokens
        self._idx = 0

    def __len__(self):
        return len(self._tokens)

    def __getitem__(self, index):
        return self._tokens[index]

    @property
    def eof(self):
        return not self._idx < len(self._tokens)

    @property
    def idx(self):
        return self._idx

    @property
    def current(self):
        return self._tokens[self._idx]

    def peek(self, offset=0):
        return self._tokens[self._idx + offset]

    def skip_while(self, *kinds):
        """
        Skip forward while token kind is present
        """
        while not self.eof:
            if not any(self._tokens[self._idx].kind == kind for kind in kinds):
                break
            self._idx += 1
        return self._idx

    def skip_until(self, *kinds):
        """
        Skip forward until token kind is present
        """
        while not self.eof:
            if any(self._tokens[self._idx].kind == kind for kind in kinds):
                break
            self._idx += 1
        return self._idx

    def pop(self):
        """
        Return current token and advance stream
        """
        if self.eof:
            raise EOFException()

        self._idx += 1
        return self._tokens[self._idx - 1]

    def expect(self, *kinds):
        """
        Expect to pop token with any of kinds
        """
        token = self.pop()
        if token.kind not in kinds:
            expected = str(kinds[0]) if len(kinds) == 1 else f"any of [{', '.join(str(kind) for kind in kinds)}]"
            raise LocationException.error(f"Expected {expected!s} got {token.kind!s}", token.location)
        return token

    def slice(self, start, end):
        return self._tokens[start:end]


def describe_location(location, first=True):
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
    def error(cls, message, location):
        return cls(message, location, "error")

    @classmethod
    def warning(cls, message, location):
        return cls(message, location, "warning")

    @classmethod
    def debug(cls, message, location):
        return cls(message, location, "debug")

    def __init__(self, message, location, severity):
        Exception.__init__(self)
        assert severity in ("debug", "warning", "error")
        self._severtity = severity
        self._message = message
        self._location = location

    def log(self, logger):
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


def add_previous(location, previous):
    """
    Add previous location
    """
    if location is None:
        return previous

    current, old_previous = location
    return (current, add_previous(old_previous, previous))


def strip_previous(location):
    """
    Strip previous location
    """
    if location is None:
        return None
    return location[0]
