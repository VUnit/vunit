# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Verilog parsing functionality
"""
from os.path import join, exists, abspath
import logging
from vunit.parsing.tokenizer import (TokenStream,
                                     Token,
                                     add_previous,
                                     strip_previous,
                                     EOFException,
                                     LocationException)
from vunit.parsing.verilog.tokens import *
from vunit.ostools import read_file
LOGGER = logging.getLogger(__name__)


class VerilogPreprocessor(object):
    """
    A Verilog preprocessor
    """

    def __init__(self, tokenizer):
        self._tokenizer = tokenizer
        self._macro_trace = set()
        self._include_trace = set()

    def preprocess(self, tokens, defines=None, include_paths=None, included_files=None):
        """
        Entry point of preprocessing
        """
        self._include_trace = set()
        self._macro_trace = set()
        return self._preprocess(tokens, defines, include_paths, included_files)

    def _preprocess(self, tokens, defines=None, include_paths=None, included_files=None):
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
            if not token.kind == PREPROCESSOR:
                result.append(token)
                continue

            try:
                result += self.preprocessor(token, stream, defines, include_paths, included_files)
            except LocationException as exc:
                exc.log(LOGGER)

        return result

    def preprocessor(self,  # pylint: disable=too-many-arguments
                     token, stream, defines, include_paths, included_files):
        """
        Handle preprocessor token
        """
        if token.value == "define":
            macro = define(token, stream)
            if macro is not None:
                defines[macro.name] = macro

        elif token.value == "undef":
            undef(token, stream, defines)

        elif token.value in ("undefineall", "resetall"):
            defines.clear()

        elif token.value == "include":
            return self.include(token, stream, include_paths, included_files, defines)

        elif token.value in ("ifdef", "ifndef"):
            try:
                tokens = self.if_statement(token, stream, defines)
                return self._preprocess(tokens,
                                        defines=defines,
                                        include_paths=include_paths,
                                        included_files=included_files)
            except EOFException:
                raise LocationException.warning(
                    "EOF reached when parsing `%s" % token.value,
                    token.location)

        elif token.value in ("celldefine", "endcelldefine", "nounconnected_drive"):
            # Ignored
            pass

        elif token.value in ("timescale", "default_nettype", "unconnected_drive"):
            # Ignore directive and arguments
            stream.skip_until(NEWLINE)

        elif token.value in defines:
            return self.expand_macro(token, stream, defines, include_paths, included_files)
        else:
            raise LocationException.debug(
                "Verilog undefined name",
                token.location)

        return []

    def expand_macro(self,  # pylint: disable=too-many-arguments
                     macro_token, stream, defines, include_paths, included_files):
        """
        Expand a macro
        """
        macro = defines[macro_token.value]
        macro_point = (strip_previous(macro_token.location), hash(frozenset(defines.keys())))
        if macro_point in self._macro_trace:
            raise LocationException.error(
                "Circular macro expansion of %s detected" % macro_token.value,
                macro_token.location)
        self._macro_trace.add(macro_point)
        tokens = self._preprocess(macro.expand_from_stream(macro_token,
                                                           stream,
                                                           previous=macro_token.location),
                                  defines=defines,
                                  include_paths=include_paths,
                                  included_files=included_files)
        self._macro_trace.remove(macro_point)
        return tokens

    @staticmethod
    def if_statement(if_token, stream, defines):
        """
        Handle if statement
        """
        def check_arg(if_token, arg):
            """
            Check the define argument of an if statement
            """
            if arg.kind != IDENTIFIER:
                raise LocationException.warning(
                    "Bad argument to `%s" % if_token.value,
                    arg.location)
            stream.skip_while(NEWLINE)

        def determine_if_taken(if_token, arg):
            """
            Determine if the branch was taken
            """
            if if_token.value in ("ifdef", "elsif"):
                return arg.value in defines
            elif if_token.value == "ifndef":
                return arg.value not in defines
            else:
                assert False

        result = []
        stream.skip_while(WHITESPACE)
        arg = stream.pop()
        check_arg(if_token, arg)

        taken = determine_if_taken(if_token, arg)
        any_taken = taken
        count = 1
        while True:
            token = stream.pop()
            if token.kind == PREPROCESSOR:
                if token.value in ("ifdef", "ifndef"):
                    count += 1
                elif token.value == "endif":
                    count -= 1
                    if count == 0:
                        break

            if count == 1 and (token.kind, token.value) == (PREPROCESSOR, "else"):
                stream.skip_while(NEWLINE)
                if not any_taken:
                    taken = True
                    any_taken = True
                else:
                    taken = False
            elif count == 1 and (token.kind, token.value) == (PREPROCESSOR, "elsif"):
                stream.skip_while(WHITESPACE)
                arg = stream.pop()
                check_arg(token, arg)
                stream.skip_while(NEWLINE)
                if not any_taken:
                    taken = determine_if_taken(token, arg)
                    any_taken = taken
                else:
                    taken = False
            elif taken:
                result.append(token)
        stream.skip_while(NEWLINE)
        return result

    def include(self,  # pylint: disable=too-many-arguments
                token, stream, include_paths, included_files, defines):
        """
        Handle `include directive
        """
        stream.skip_while(WHITESPACE)
        try:
            tok = stream.pop()
        except EOFException:
            raise LocationException.warning(
                "EOF reached when parsing `include argument",
                token.location)

        if tok.kind == PREPROCESSOR:
            if tok.value in defines:
                macro = defines[tok.value]
            else:
                raise LocationException.warning(
                    "Verilog `include argument not defined",
                    tok.location)

            expanded_tokens = self.expand_macro(tok,
                                                stream,
                                                defines,
                                                include_paths,
                                                included_files)

            if len(expanded_tokens) == 0:
                raise LocationException.warning("Verilog `include has bad argument, empty define `%s" % macro.name,
                                                tok.location)

            if expanded_tokens[0].kind != STRING:
                raise LocationException.warning("Verilog `include has bad argument",
                                                expanded_tokens[0].location)

            file_name_tok = expanded_tokens[0]

        elif tok.kind == STRING:
            file_name_tok = tok
        else:
            raise LocationException.warning("Verilog `include bad argument",
                                            tok.location)

        included_file = find_included_file(include_paths, file_name_tok.value)
        included_files.append((file_name_tok.value, included_file))
        if included_file is None:
            # Is debug message since there are so many builtin includes in tools
            raise LocationException.debug(
                "Could not find `include file %s" % file_name_tok.value,
                file_name_tok.location)

        include_point = (strip_previous(token.location), hash(frozenset(defines.keys())))
        if include_point in self._include_trace:
            raise LocationException.error(
                "Circular `include of %s detected" % file_name_tok.value,
                file_name_tok.location)
        self._include_trace.add(include_point)

        included_tokens = self._tokenizer.tokenize(read_file(included_file),
                                                   file_name=included_file,
                                                   previous_location=token.location)
        included_tokens = self._preprocess(included_tokens,
                                           defines,
                                           include_paths,
                                           included_files)
        self._include_trace.remove(include_point)
        return included_tokens


def find_included_file(include_paths, file_name):
    """
    Find the file to include given include_paths
    """
    for include_path in include_paths:
        full_name = abspath(join(include_path, file_name))
        if exists(full_name):
            return full_name
    return None


def undef(undef_token, stream, defines):
    """
    Handles undef directive
    """
    stream.skip_while(WHITESPACE, NEWLINE)
    try:
        name_token = stream.pop()
    except EOFException:
        raise LocationException.warning("EOF reached when parsing `undef",
                                        undef_token.location)

    if name_token.kind != IDENTIFIER:
        raise LocationException.warning("Bad argument to `undef",
                                        name_token.location)

    if name_token.value not in defines:
        raise LocationException.warning("`undef argument was not previously defined",
                                        name_token.location)

    del defines[name_token.value]


def define(define_token, stream):
    """
    Handle a `define directive
    """
    stream.skip_while(WHITESPACE, NEWLINE)
    try:
        name_token = stream.pop()
    except EOFException:
        raise LocationException.warning("Verilog `define without argument",
                                        define_token.location)

    if name_token.kind != IDENTIFIER:
        raise LocationException.warning("Verilog `define invalid name",
                                        name_token.location)

    name = name_token.value

    try:
        token = stream.pop()
    except EOFException:
        # Empty define
        return Macro(name)

    if token.kind in (NEWLINE,):
        # Empty define
        return Macro(name)

    if token.kind in (WHITESPACE,):
        # Define without arguments
        args = tuple()
        defaults = {}
    elif token.kind == LPAR:
        lpar_token = token
        args = tuple()
        defaults = {}

        try:
            while token.kind != RPAR:
                if token.kind == IDENTIFIER:
                    argname = token.value
                    args = args + (argname,)
                    token = stream.pop()
                    if token.kind == EQUAL:
                        token = stream.pop()
                        defaults[argname] = [token]
                        token = stream.pop()
                else:
                    token = stream.pop()
        except EOFException:
            raise LocationException.warning(
                "EOF reached when parsing `define argument list",
                lpar_token.location)

    stream.skip_while(WHITESPACE)
    start = stream.idx
    end = stream.skip_until(NEWLINE)
    if not stream.eof:
        stream.pop()
    return Macro(name,
                 tokens=stream.slice(start, end),
                 args=args,
                 defaults=defaults)


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

    def expand(self, values, previous):
        """
        Expand macro with actual values, returns a list of expanded tokens
        """
        tokens = []
        for token in self.tokens:
            if token.kind == IDENTIFIER and token.value in self.args:
                idx = self.args.index(token.value)
                value = values[idx]
                tokens += value
            else:
                tokens.append(token)
        return [Token(tok.kind, tok.value, add_previous(tok.location, previous))
                for tok in tokens]

    def __eq__(self, other):
        return ((self.name == other.name) and
                (self.tokens == other.tokens) and
                (self.args == other.args) and
                (self.defaults == other.defaults))

    def expand_from_stream(self, token, stream, previous=None):
        """
        Expand macro consuming arguments from the stream
        returns the expanded tokens
        """
        if self.num_args == 0:
            values = []
        else:
            try:
                values = self._parse_macro_actuals(token, stream)
            except EOFException:
                raise LocationException.warning("EOF reached when parsing `define actuals",
                                                location=token.location)

            # Bind defaults
            if len(values) < len(self.args):
                for i in range(len(values), len(self.args)):
                    name = self.args[i]
                    if name in self.defaults:
                        values.append(self.defaults[name])
                    else:
                        raise LocationException.warning(
                            "Missing value for argument %s" % name,
                            token.location)

            elif len(values) > len(self.args):
                raise LocationException.warning("Too many arguments got %i expected %i" %
                                                (len(values), len(self.args)),
                                                token.location)

        return self.expand(values, previous)

    @staticmethod
    def _parse_macro_actuals(define_token, stream):
        """
        Parse the actual values of macro call such as
        1 2 in `macro(1, 2)
        """
        token = stream.pop()
        if token.kind != LPAR:
            raise LocationException.warning("Bad `define argument list",
                                            define_token.location)
        token = stream.pop()
        value = []
        values = []
        while token.kind != RPAR:
            if token.kind == COMMA:
                values.append(value)
                value = []
            else:
                value.append(token)
            token = stream.pop()

        values.append(value)
        return values
