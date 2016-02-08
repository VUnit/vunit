# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods

"""
Test of the Verilog preprocessor
"""

from os.path import join, dirname, exists
import os
from vunit.ostools import renew_path, write_file

from unittest import TestCase
from vunit.parsing.verilog.preprocess import VerilogPreprocessor, Macro
from vunit.parsing.verilog.tokenizer import tokenize, Token
from vunit.test.mock_2or3 import mock
import shutil


class TestVerilogPreprocessor(TestCase):
    """
    Test of the Verilog preprocessor
    """

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_verilog_preprocessor_out")
        renew_path(self.output_path)
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.output_path)

    def test_non_preprocess_tokens_are_kept(self):
        defines = {}
        tokens = tokenize('"hello"ident/*comment*///comment')
        pp_tokens = preprocess('"hello"ident/*comment*///comment', defines)
        self.assertEqual(pp_tokens, tokens)
        self.assertEqual(defines, {})

    def test_preprocess_define_without_value(self):
        defines = {}
        tokens = preprocess("`define foo", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo")})

        defines = {}
        tokens = preprocess("`define foo\nkeep", defines)
        self.assertEqual(tokens, tokenize("keep"))
        self.assertEqual(defines, {"foo": Macro("foo")})

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_broken_define(self, logger):
        defines = {}
        tokens = preprocess_loc("`define", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "Verilog `define without argument\n%s",
            "at fn.v line 1:\n"
            "`define\n"
            "~~~~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_broken_define_first_argument(self, logger):
        defines = {}
        tokens = preprocess_loc('`define "foo"', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "Verilog `define invalid name\n%s",
            "at fn.v line 1:\n"
            '`define "foo"\n'
            "        ~~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_broken_define_argument_list(self, logger):
        defines = {}
        tokens = preprocess_loc('`define foo(', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo(\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo(a', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo(a\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo(a=', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo(a=\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo(a=b', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo(a=b\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo(a=)', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo(a=)\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo("a"', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo("a"\n'
            "           ~")
        logger.warning.reset_mock()

        defines = {}
        tokens = preprocess_loc('`define foo("a"=', defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n"
            '`define foo("a"=\n'
            "           ~")
        logger.warning.reset_mock()

    def test_preprocess_define_with_value(self):
        defines = {}
        tokens = preprocess("`define foo bar \"abc\"", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo", tokenize("bar \"abc\""))})

    def test_preprocess_define_with_lpar_value(self):
        defines = {}
        tokens = preprocess("`define foo (bar)", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines, {"foo": Macro("foo", tokenize("(bar)"))})

    def test_preprocess_define_with_one_arg(self):
        defines = {}
        tokens = preprocess("`define foo(arg)arg 123", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo", tokenize("arg 123"), args=("arg",))})

    def test_preprocess_define_with_one_arg_ignores_initial_space(self):
        defines = {}
        tokens = preprocess("`define foo(arg) arg 123", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo", tokenize("arg 123"), args=("arg",))})

    def test_preprocess_define_with_multiple_args(self):
        defines = {}
        tokens = preprocess("`define foo( arg1, arg2)arg1 arg2", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo", tokenize("arg1 arg2"), args=("arg1", "arg2"))})

    def test_preprocess_define_with_default_values(self):
        defines = {}
        tokens = preprocess("`define foo(arg1, arg2=default)arg1 arg2", defines)
        self.assertEqual(tokens, [])
        self.assertEqual(defines,
                         {"foo": Macro("foo",
                                       tokenize("arg1 arg2"),
                                       args=("arg1", "arg2"),
                                       defaults={"arg2": tokenize("default")})})

    def test_preprocess_substitute_define_without_args(self):
        tokens = preprocess("""\
`define foo bar \"abc\"
`foo""")
        self.assertEqual(tokens, tokenize("bar \"abc\""))

    def test_preprocess_substitute_define_with_one_arg(self):
        tokens = preprocess("""\
`define foo(arg)arg 123
`foo(hello hey)""")
        self.assertEqual(tokens, tokenize("hello hey 123"))

    def test_preprocess_substitute_define_with_multile_args(self):
        tokens = preprocess("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2, hello)""")
        self.assertEqual(tokens, tokenize("1 2, hello"))

    def test_preprocess_substitute_define_with_default_values(self):
        defines = {}
        tokens = preprocess("""\
`define foo(arg1, arg2=default)arg1 arg2
`foo(1)""", defines)
        self.assertEqual(tokens, tokenize("1 default"))

    def test_preprocess_substitute_define_broken_args(self):
        tokens = preprocess("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2)""")
        self.assertEqual(tokens, tokenize(""))

        tokens = preprocess("""\
`define foo(arg1, arg2)arg1,arg2
`foo""")
        self.assertEqual(tokens, tokenize(""))

        tokens = preprocess("""\
`define foo(arg1, arg2)arg1,arg2
`foo(""")
        self.assertEqual(tokens, tokenize(""))

        tokens = preprocess("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1""")
        self.assertEqual(tokens, tokenize(""))

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_substitute_define_missing_argument(self, logger):
        tokens = preprocess_loc("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1)""")
        self.assert_equal_noloc(tokens, tokenize(""))
        logger.warning.assert_called_once_with(
            "Missing value for argument arg2\n%s",
            "at fn.v line 2:\n"
            '`foo(1)\n'
            "~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_substitute_define_too_many_argument(self, logger):
        tokens = preprocess_loc("""\
`define foo(arg1)arg1
`foo(1, 2)""")
        self.assert_equal_noloc(tokens, tokenize(""))
        logger.warning.assert_called_once_with(
            "Too many arguments got 2 expected 1\n%s",
            "at fn.v line 2:\n"
            '`foo(1, 2)\n'
            "~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_substitute_define_eof(self, logger):
        tokens = preprocess_loc("""\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2""")
        self.assert_equal_noloc(tokens, tokenize(""))
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `define actuals\n%s",
            "at fn.v line 2:\n"
            '`foo(1 2\n'
            "~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_substitute_undefined(self, logger):
        defines = {}
        tokens = preprocess_loc('`foo', defines)
        self.assert_equal_noloc(tokens, [])
        self.assertEqual(defines, {})
        # Debug since there are many custon `names in tools
        logger.debug.assert_called_once_with(
            "Verilog undefined name\n%s",
            "at fn.v line 1:\n"
            '`foo\n'
            "~~~~")

    def test_preprocess_include_directive(self):
        self.write_file("include.svh", "hello hey")
        included_files = []
        tokens = preprocess('`include "include.svh"',
                            include_paths=[self.output_path],
                            included_files=included_files)
        self.assertEqual(tokens, tokenize("hello hey"))
        self.assertEqual(included_files, [join(self.output_path, "include.svh")])

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_missing_file(self, logger):

        included_files = []
        tokens = preprocess_loc('`include "missing.svh"',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize(""))
        self.assertEqual(included_files, [])
        # Is debug message since there are so many builtin includes in tools
        logger.debug.assert_called_once_with(
            "Could not find `include file missing.svh\n%s",
            "at fn.v line 1:\n"
            '`include "missing.svh"\n'
            "         ~~~~~~~~~~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_missing_argument(self, logger):
        included_files = []
        tokens = preprocess_loc('`include',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assertEqual(tokens, [])
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `include argument\n%s",
            "at fn.v line 1:\n"
            '`include\n'
            "~~~~~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_bad_argument(self, logger):
        included_files = []
        self.write_file("include.svh", "hello hey")
        tokens = preprocess_loc('`include foo "include.svh"',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize(' "include.svh"'))
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "at fn.v line 1:\n"
            '`include foo "include.svh"\n'
            "         ~~~")

    def test_preprocess_include_directive_from_define(self):
        included_files = []
        self.write_file("include.svh", "hello hey")
        tokens = preprocess('''\
`define inc "include.svh"
`include `inc''',
                            include_paths=[self.output_path],
                            included_files=included_files)
        self.assertEqual(tokens, tokenize('hello hey'))
        self.assertEqual(included_files, [join(self.output_path, "include.svh")])

    def test_preprocess_include_directive_from_define_with_args(self):
        included_files = []
        self.write_file("include.svh", "hello hey")
        tokens = preprocess('''\
`define inc(a) a
`include `inc("include.svh")''',
                            include_paths=[self.output_path],
                            included_files=included_files)
        self.assertEqual(tokens, tokenize('hello hey'))
        self.assertEqual(included_files, [join(self.output_path, "include.svh")])

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_from_define_bad_argument(self, logger):
        included_files = []
        tokens = preprocess_loc('''\
`define inc foo
`include `inc
keep''',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize('\nkeep'))
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "Verilog `include has bad argument\n%s",
            "from fn.v line 2:\n"
            '`include `inc\n'
            '         ~~~~\n'
            "at fn.v line 1:\n"
            '`define inc foo\n'
            "            ~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_from_empty_define(self, logger):
        included_files = []
        tokens = preprocess_loc('''\
`define inc
`include `inc
keep''',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize('\nkeep'))
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "Verilog `include has bad argument, empty define `inc\n%s",
            "at fn.v line 2:\n"
            '`include `inc\n'
            "         ~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_include_directive_from_define_not_defined(self, logger):
        included_files = []
        tokens = preprocess_loc('''\
`include `inc''',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize(''))
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "Verilog `include argument not defined\n%s",
            "at fn.v line 1:\n"
            '`include `inc\n'
            "         ~~~~")

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_error_in_include_file(self, logger):
        included_files = []
        self.write_file("include.svh", '`include foo')
        tokens = preprocess_loc('\n\n`include "include.svh"',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize('\n\n'))
        self.assertEqual(included_files, [join(self.output_path, "include.svh")])
        logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "from fn.v line 3:\n"
            '`include "include.svh"\n'
            "~~~~~~~~\n"
            "at include.svh line 1:\n"
            '`include foo\n'
            '         ~~~')

    def test_preprocess_macros_are_recursively_expanded(self):
        included_files = []
        tokens = preprocess_loc('''\
`define foo `bar
`define bar xyz
`foo
`define bar abc
`foo
''',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize('xyz\nabc\n'))
        self.assertEqual(included_files, [])

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_preprocess_error_in_expanded_define(self, logger):
        included_files = []
        tokens = preprocess_loc('''\
`define foo `include wrong
`foo
''',
                                include_paths=[self.output_path],
                                included_files=included_files)
        self.assert_equal_noloc(tokens, tokenize('\n'))
        self.assertEqual(included_files, [])
        logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "from fn.v line 2:\n"
            '`foo\n'
            '~~~~\n'
            "at fn.v line 1:\n"
            '`define foo `include wrong\n'
            "                     ~~~~~")

    def test_ifndef_taken(self):
        tokens = preprocess_loc('''\
`ifndef foo
taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("taken\nkeep"))

    def test_ifdef_taken(self):
        tokens = preprocess_loc('''\
`define foo
`ifdef foo
taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("taken\nkeep"))

    def test_ifdef_else_taken(self):
        tokens = preprocess_loc('''\
`define foo
`ifdef foo
taken
`else
else
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("taken\nkeep"))

    def test_ifdef_not_taken(self):
        tokens = preprocess_loc('''\
`ifdef foo
taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("keep"))

    def test_ifdef_else_not_taken(self):
        tokens = preprocess_loc('''\
`ifdef foo
taken
`else
else
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("else\nkeep"))

    def test_ifdef_elsif_taken(self):
        tokens = preprocess_loc('''\
`define foo
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("taken\nkeep"))

    def test_ifdef_elsif_elseif_taken(self):
        tokens = preprocess_loc('''\
`define bar
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("elsif_taken\nkeep"))

    def test_ifdef_elsif_else_taken(self):
        tokens = preprocess_loc('''\
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep''')
        self.assert_equal_noloc(tokens, tokenize("else_taken\nkeep"))

    def test_nested_ifdef(self):
        tokens = preprocess_loc('''\
`define foo
`ifdef foo
outer_before
`ifdef bar
inner_ifndef
`else
inner_else
`endif
`ifdef bar
inner_ifndef
`elsif foo
inner_elsif
`endif
outer_after
`endif
keep''')
        self.assert_equal_noloc(tokens,
                                tokenize("outer_before\n"
                                         "inner_else\n"
                                         "inner_elsif\n"
                                         "outer_after\n"
                                         "keep"))

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ifdef_eof(self, logger):
        tokens = preprocess_loc('''\
`ifdef foo
taken''')
        self.assert_equal_noloc(tokens, tokenize(""))
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `ifdef\n%s",
            "at fn.v line 1:\n"
            '`ifdef foo\n'
            '~~~~~~')

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ifdef_bad_argument(self, logger):
        tokens = preprocess_loc('''\
`ifdef "hello"
keep''')
        self.assert_equal_noloc(tokens, tokenize("\nkeep"))
        logger.warning.assert_called_once_with(
            "Bad argument to `ifdef\n%s",
            "at fn.v line 1:\n"
            '`ifdef "hello"\n'
            '       ~~~~~~~')

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_elsif_bad_argument(self, logger):
        tokens = preprocess_loc('''\
`ifdef bar
`elsif "hello"
keep''')
        self.assert_equal_noloc(tokens, tokenize("\nkeep"))
        logger.warning.assert_called_once_with(
            "Bad argument to `elsif\n%s",
            "at fn.v line 2:\n"
            '`elsif "hello"\n'
            '       ~~~~~~~')

    def test_undefineall(self):
        defines = {}
        tokens = preprocess('''\
`define foo keep
`define bar keep2
`foo
`undefineall''', defines)
        self.assert_equal_noloc(tokens, tokenize("keep\n"))
        self.assertEqual(defines, {})

    def test_resetall(self):
        defines = {}
        tokens = preprocess('''\
`define foo keep
`define bar keep2
`foo
`resetall''', defines)
        self.assert_equal_noloc(tokens, tokenize("keep\n"))
        self.assertEqual(defines, {})

    def test_undef(self):
        defines = {}
        tokens = preprocess('''\
`define foo keep
`define bar keep2
`foo
`undef foo''', defines)
        self.assert_equal_noloc(tokens, tokenize("keep\n"))
        self.assertEqual(defines, {"bar": Macro("bar", tokenize("keep2"))})

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_undef_eof(self, logger):
        defines = {}
        tokens = preprocess_loc('`undef')
        self.assert_equal_noloc(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "EOF reached when parsing `undef\n%s",
            "at fn.v line 1:\n"
            '`undef\n'
            '~~~~~~')

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_undef_bad_argument(self, logger):
        defines = {}
        tokens = preprocess_loc('`undef "foo"', defines)
        self.assert_equal_noloc(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "Bad argument to `undef\n%s",
            "at fn.v line 1:\n"
            '`undef "foo"\n'
            '       ~~~~~')

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_undef_not_defined(self, logger):
        defines = {}
        tokens = preprocess_loc('`undef foo', defines)
        self.assert_equal_noloc(tokens, [])
        self.assertEqual(defines, {})
        logger.warning.assert_called_once_with(
            "`undef argument was not previously defined\n%s",
            "at fn.v line 1:\n"
            '`undef foo\n'
            '       ~~~')

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ignores_celldefine(self, logger):
        tokens = preprocess_loc('`celldefine`endcelldefine keep')
        self.assert_equal_noloc(tokens, tokenize(" keep"))
        assert not logger.debug.called
        assert not logger.warning.called

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ignores_timescale(self, logger):
        tokens = preprocess_loc('`timescale 1 ns / 1 ps\nkeep')
        self.assert_equal_noloc(tokens, tokenize("\nkeep"))
        assert not logger.debug.called
        assert not logger.warning.called

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ignores_default_nettype(self, logger):
        tokens = preprocess_loc('`default_nettype none\nkeep')
        self.assert_equal_noloc(tokens, tokenize("\nkeep"))
        assert not logger.debug.called
        assert not logger.warning.called

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ignores_nounconnected_drive(self, logger):
        tokens = preprocess_loc('`nounconnected_drive keep')
        self.assert_equal_noloc(tokens, tokenize(" keep"))
        assert not logger.debug.called
        assert not logger.warning.called

    @mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True)
    def test_ignores_unconnected_drive(self, logger):
        tokens = preprocess_loc('`unconnected_drive pull1\nkeep')
        self.assert_equal_noloc(tokens, tokenize("\nkeep"))
        assert not logger.debug.called
        assert not logger.warning.called

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

    def assert_equal_noloc(self, expected, got):
        """
        Assert that two token lists are equal disregarding locations
        """
        def transform(tokens):
            return [Token(tok.kind, tok.value, None) for tok in tokens]
        self.assertEqual(transform(expected), transform(got))


def preprocess_loc(code, defines=None, file_name="fn.v", include_paths=None, included_files=None):
    """
    Preprocess with location information
    """

    write_file(file_name, code)
    tokens = tokenize(code, file_name=file_name, create_locations=True)
    tokens = VerilogPreprocessor().preprocess(tokens, defines, include_paths, included_files)
    return tokens


def preprocess(code, defines=None, include_paths=None, included_files=None):
    """
    Preprocess without location information
    """
    tokens = tokenize(code, file_name=None, create_locations=False)
    return VerilogPreprocessor(create_locations=False).preprocess(tokens=tokens,
                                                                  defines=defines,
                                                                  include_paths=include_paths,
                                                                  included_files=included_files)
