# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
A general tokenizer
"""

import collections
import re

Token = collections.namedtuple("Token", ["kind", "value"])


def new_token_kind(name):
    """
    Create a new token kind with nice __repr__
    """
    cls = type(name, (object,), {"__repr__": lambda self: name})
    return cls()


class Tokenizer(object):
    """
    Maintain a prioritized list of token regex
    """

    def __init__(self):
        self._regexs = []
        self._assoc = {}
        self._regex = None

    def add(self, name, regex, func=None):
        """
        Add token type
        """
        key = chr(ord('a') + len(self._regexs))
        self._regexs.append((key, regex))
        kind = new_token_kind(name)
        self._assoc[key] = (kind, func)
        return kind

    def finalize(self):
        self._regex = re.compile("|".join("(?P<%s>%s)" % spec for spec in self._regexs), re.VERBOSE | re.MULTILINE)

    def tokenize(self, code):
        """
        Tokenize the code
        """
        tokens = []
        start = 0
        while True:
            match = self._regex.search(code, pos=start)
            if match is None:
                break
            start = match.end()
            key = match.lastgroup
            kind, func = self._assoc[key]
            value = match.group(match.lastgroup)
            token = Token(kind, value)
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

    def skip_while(self, kind):
        """
        Skip forward while token kind is present
        """
        while (not self.eof) and self._tokens[self._idx].kind == kind:
            self._idx += 1
        return self._idx

    def skip_until(self, kind):
        """
        Skip forward until token kind is present
        """
        while (not self.eof) and self._tokens[self._idx].kind != kind:
            self._idx += 1
        return self._idx

    def pop(self):
        """
        Return current token and advance stream
        """
        self._idx += 1
        return self._tokens[self._idx - 1]

    def slice(self, start, end):
        return self._tokens[start:end]
