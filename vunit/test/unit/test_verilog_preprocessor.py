# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the Verilog preprocessor
"""

from os.path import join, dirname, exists
import os
from vunit.ostools import renew_path

from unittest import TestCase
from vunit.parsing.verilog.preprocess import preprocess, Macro
from vunit.parsing.verilog.tokenizer import tokenize


class TestVerilogPreprocessor(TestCase):
    """
    Test of the Verilog preprocessor
    """

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_verilog_preprocessor_out")
        renew_path(self.output_path)

    def test_non_preprocess_tokens_are_kept(self):
        defines = {}
        tokens = tokenize('"hello"ident/*comment*///comment')
        pp_tokens = preprocess(tokenize('"hello"ident/*comment*///comment'), defines)
        self.assertEqual(pp_tokens, tokens)
        self.assertEqual(defines, {})

    def test_preprocess_define_without_value(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo"), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo")})

    def test_preprocess_define_with_value(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo bar \"abc\""), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo", tokenize("bar \"abc\""))})

    def test_preprocess_define_with_lpar_value(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo (bar)"), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo", tokenize("(bar)"))})

    def test_preprocess_define_with_one_arg(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo(arg)arg 123"), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo", tokenize("arg 123"), args=("arg",))})

    def test_preprocess_define_with_multiple_args(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo( arg1, arg2)arg1 arg2"), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo", tokenize("arg1 arg2"), args=("arg1", "arg2"))})

    def test_preprocess_define_with_default_values(self):
        defines = {}
        tokens = preprocess(tokenize("`define foo(arg1, arg2=default)arg1 arg2"), defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo",
                                       tokenize("arg1 arg2"),
                                       args=("arg1", "arg2"),
                                       defaults={"arg2": tokenize("default")})})

    def test_preprocess_substitute_define_without_args(self):
        tokens = preprocess(tokenize("""\
`define foo bar \"abc\"
`foo"""))
        self.assertEqual(tokens, tokenize("bar \"abc\""))

    def test_preprocess_substitute_define_with_one_arg(self):
        tokens = preprocess(tokenize("""\
`define foo(arg)arg 123
`foo(hello hey)"""))
        self.assertEqual(tokens, tokenize("hello hey 123"))

    def test_preprocess_substitute_define_with_multile_args(self):
        tokens = preprocess(tokenize("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2, hello)"""))
        self.assertEqual(tokens, tokenize("1 2, hello"))

    def test_preprocess_substitute_define_with_default_values(self):
        defines = {}
        tokens = preprocess(tokenize("""\
`define foo(arg1, arg2=default)arg1 arg2
`foo(1)"""), defines)
        self.assertEqual(tokens, tokenize("1 default"))

    def test_preprocess_include_directive(self):
        self.write_file("include.svh", "hello hey")
        included_files = []
        tokens = preprocess(tokenize('`include "include.svh"'),
                            include_paths=[self.output_path],
                            included_files=included_files)
        self.assertEqual(tokens, tokenize("hello hey"))
        self.assertEqual(included_files, [join(self.output_path, "include.svh")])

    def write_file(self, file_name, contents):
        """
        Write file with contents into output path
        """
        full_name = join(self.output_path, file_name)
        full_path = dirname(full_name)
        if not exists(full_path):
            os.makedirs(dirname(full_path))
        with open(full_name, "w") as fptr:
            fptr.write(contents)
