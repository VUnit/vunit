# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Verilog parsing functionality
"""
from os.path import join, exists

from vunit.parsing.tokenizer import TokenStream
import vunit.parsing.verilog.tokenizer as tokenizer
from vunit.parsing.verilog.tokenizer import tokenize


def preprocess(tokens, defines=None, include_paths=None, included_files=None):
    """
    Pre-process tokens while filling in defines
    """
    stream = TokenStream(tokens)
    include_paths = [] if include_paths is None else include_paths
    included_files = [] if included_files is None else included_files
    defines = {} if defines is None else defines
    result = []

    while not stream.eof:
        token = stream.pop()
        if not token.kind == tokenizer.PREPROCESSOR:
            result.append(token)
            continue

        if token.value == "define":
            macro = define(stream)
            defines[macro.name] = macro

        if token.value == "include":
            stream.skip_until(tokenizer.STRING)
            file_name = stream.pop().value

            full_name = None
            for include_path in include_paths:
                full_name = join(include_path, file_name)
                if exists(full_name):
                    break
            else:
                assert False
            included_files.append(full_name)
            with open(full_name, "r") as fptr:
                included_tokens = tokenize(fptr.read())
            result += preprocess(included_tokens, defines, include_paths, included_files)

        elif token.value in defines:
            macro = defines[token.value]
            if macro.num_args == 0:
                values = []
            else:
                values = parse_macro_actuals(stream)
            result += macro.expand(values)

    return result


def define(stream):
    """
    Handle a `define directive
    """
    stream.skip_while(tokenizer.WHITESPACE)
    name_token = stream.pop()
    assert name_token.kind == tokenizer.IDENTIFIER
    name = name_token.value

    if stream.eof:
        return Macro(name)

    token = stream.pop()
    if token.kind in (tokenizer.WHITESPACE, tokenizer.NEWLINE):
        # Define without arguments
        args = tuple()
        defaults = {}
    elif token.kind == tokenizer.LPAR:
        args = tuple()
        defaults = {}
        while token.kind != tokenizer.RPAR:
            if token.kind == tokenizer.IDENTIFIER:
                argname = token.value
                args = args + (argname,)
                token = stream.pop()
                if token.kind == tokenizer.EQUAL:
                    token = stream.pop()
                    defaults[argname] = [token]
                    token = stream.pop()
            else:
                token = stream.pop()

    start = stream.idx
    end = stream.skip_until(tokenizer.NEWLINE)
    if not stream.eof:
        stream.pop()
    return Macro(name,
                 tokens=stream.slice(start, end),
                 args=args,
                 defaults=defaults)


def parse_macro_actuals(stream):
    """
    Parse the actual values of macro call such as
    1 2 in `macro(1, 2)
    """
    token = stream.pop()
    assert token.kind == tokenizer.LPAR
    token = stream.pop()

    value = []
    values = []
    while token.kind != tokenizer.RPAR:
        if token.kind == tokenizer.COMMA:
            values.append(value)
            value = []
        else:
            value.append(token)
        token = stream.pop()
    values.append(value)
    return values


class Macro(object):
    """
    A `define macro with zero or more arguments
    """

    def __init__(self, name, tokens=None, args=tuple(), defaults=None):
        self.name = name
        self.tokens = [] if tokens is None else tokens
        self.args = args
        self.defaults = {} if defaults is None else defaults

    @property
    def num_args(self):
        return len(self.args)

    def __repr__(self):
        return "Macro(%r, %r %r, %r)" % (self.name, self.tokens, self.args, self.defaults)

    def expand(self, values):
        """
        Expand macro with actual values, returns a list of expanded tokens
        """
        tokens = []
        for token in self.tokens:
            if token.kind == tokenizer.IDENTIFIER and token.value in self.args:
                idx = self.args.index(token.value)
                if idx >= len(values):
                    value = self.defaults[token.value]
                else:
                    value = values[idx]
                tokens += value
            else:
                tokens.append(token)
        return tokens

    def __eq__(self, other):
        return ((self.name == other.name) and
                (self.tokens == other.tokens) and
                (self.args == other.args) and
                (self.defaults == other.defaults))
