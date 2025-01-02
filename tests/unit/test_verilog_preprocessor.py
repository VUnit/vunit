# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods
# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Test of the Verilog preprocessor
"""

from pathlib import Path
import os
from unittest import TestCase, mock
import shutil
from vunit.ostools import renew_path, write_file
from vunit.parsing.verilog.preprocess import VerilogPreprocessor, Macro
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.tokenizer import Token


class TestVerilogPreprocessor(TestCase):
    """
    Test of the Verilog preprocessor
    """

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_verilog_preprocessor_out")
        renew_path(self.output_path)
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.output_path)

    def test_non_preprocess_tokens_are_kept(self):
        result = self.preprocess('"hello"ident/*comment*///comment')
        result.assert_has_tokens('"hello"ident/*comment*///comment')
        result.assert_no_defines()

    def test_preprocess_define_without_value(self):
        result = self.preprocess("`define foo")
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo")})

        result = self.preprocess("`define foo\nkeep")
        result.assert_has_tokens("keep")
        result.assert_has_defines({"foo": Macro("foo")})

    def test_preprocess_define_with_value(self):
        result = self.preprocess('`define foo bar "abc"')
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo", tokenize('bar "abc"'))})

    def test_preprocess_define_with_lpar_value(self):
        result = self.preprocess("`define foo (bar)")
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo", tokenize("(bar)"))})

    def test_preprocess_define_with_one_arg(self):
        result = self.preprocess("`define foo(arg)arg 123")
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo", tokenize("arg 123"), args=("arg",))})

    def test_preprocess_define_with_one_arg_ignores_initial_space(self):
        result = self.preprocess("`define foo(arg) arg 123")
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo", tokenize("arg 123"), args=("arg",))})

    def test_preprocess_define_with_multiple_args(self):
        result = self.preprocess("`define foo( arg1, arg2)arg1 arg2")
        result.assert_has_tokens("")
        result.assert_has_defines({"foo": Macro("foo", tokenize("arg1 arg2"), args=("arg1", "arg2"))})

    def test_preprocess_define_with_default_values(self):
        result = self.preprocess("`define foo(arg1, arg2=default)arg1 arg2")
        result.assert_has_tokens("")
        result.assert_has_defines(
            {
                "foo": Macro(
                    "foo",
                    tokenize("arg1 arg2"),
                    args=("arg1", "arg2"),
                    defaults={"arg2": tokenize("default")},
                )
            }
        )

    def test_preprocess_substitute_define_without_args(self):
        result = self.preprocess(
            """\
`define foo bar \"abc\"
`foo"""
        )
        result.assert_has_tokens('bar "abc"')

    def test_preprocess_substitute_define_with_one_arg(self):
        result = self.preprocess(
            """\
`define foo(arg)arg 123
`foo(hello hey)"""
        )
        result.assert_has_tokens("hello hey 123")

    def test_preprocess_substitute_define_with_space_before_arg(self):
        result = self.preprocess(
            """\
`define foo(arg) arg
`foo (hello)"""
        )
        result.assert_has_tokens("hello")

    def test_preprocess_substitute_define_no_args(self):
        result = self.preprocess(
            """\
`define foo bar
`foo (hello)"""
        )
        result.assert_has_tokens("bar (hello)")

    def test_preprocess_substitute_define_with_multile_args(self):
        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2, hello)"""
        )
        result.assert_has_tokens("1 2, hello")

    def test_preprocess_substitute_define_with_default_values(self):
        result = self.preprocess(
            """\
`define foo(arg1, arg2=default)arg1 arg2
`foo(1)"""
        )
        result.assert_has_tokens("1 default")

    def test_preprocess_include_directive(self):
        self.write_file("include.svh", "hello hey")
        result = self.preprocess('`include "include.svh"', include_paths=[self.output_path])
        result.assert_has_tokens("hello hey")
        result.assert_included_files([str(Path(self.output_path) / "include.svh")])

    def test_detects_circular_includes(self):
        self.write_file("include1.svh", '`include "include2.svh"')
        self.write_file("include2.svh", '`include "include1.svh"')
        result = self.preprocess('`include "include1.svh"', include_paths=[self.output_path])
        result.logger.error.assert_called_once_with(
            "Circular `include of include2.svh detected\n%s",
            "from fn.v line 1:\n"
            '`include "include1.svh"\n'
            "~~~~~~~~\n"
            "from include1.svh line 1:\n"
            '`include "include2.svh"\n'
            "~~~~~~~~\n"
            "from include2.svh line 1:\n"
            '`include "include1.svh"\n'
            "~~~~~~~~\n"
            "at include1.svh line 1:\n"
            '`include "include2.svh"\n'
            "         ~~~~~~~~~~~~~~",
        )

    def test_detects_circular_include_of_self(self):
        self.write_file("include.svh", '`include "include.svh"')
        result = self.preprocess('`include "include.svh"', include_paths=[self.output_path])
        result.logger.error.assert_called_once_with(
            "Circular `include of include.svh detected\n%s",
            "from fn.v line 1:\n"
            '`include "include.svh"\n'
            "~~~~~~~~\n"
            "from include.svh line 1:\n"
            '`include "include.svh"\n'
            "~~~~~~~~\n"
            "at include.svh line 1:\n"
            '`include "include.svh"\n'
            "         ~~~~~~~~~~~~~",
        )

    def test_does_not_detect_non_circular_includes(self):
        self.write_file("include3.svh", "keep")
        self.write_file("include1.svh", '`include "include3.svh"\n`include "include2.svh"')
        self.write_file("include2.svh", '`include "include3.svh"')
        result = self.preprocess(
            '`include "include1.svh"\n`include "include2.svh"',
            include_paths=[self.output_path],
        )
        result.assert_no_log()

    def test_detects_circular_macro_expansion_of_self(self):
        result = self.preprocess(
            """
`define foo `foo
`foo
"""
        )
        result.logger.error.assert_called_once_with(
            "Circular macro expansion of foo detected\n%s",
            "from fn.v line 3:\n"
            "`foo\n"
            "~~~~\n"
            "from fn.v line 2:\n"
            "`define foo `foo\n"
            "            ~~~~\n"
            "at fn.v line 2:\n"
            "`define foo `foo\n"
            "            ~~~~",
        )

    def test_detects_circular_macro_expansion(self):
        result = self.preprocess(
            """
`define foo `bar
`define bar `foo
`foo
"""
        )
        result.logger.error.assert_called_once_with(
            "Circular macro expansion of bar detected\n%s",
            "from fn.v line 4:\n"
            "`foo\n"
            "~~~~\n"
            "from fn.v line 2:\n"
            "`define foo `bar\n"
            "            ~~~~\n"
            "from fn.v line 3:\n"
            "`define bar `foo\n"
            "            ~~~~\n"
            "at fn.v line 2:\n"
            "`define foo `bar\n"
            "            ~~~~",
        )

    def test_does_not_detect_non_circular_macro_expansion(self):
        result = self.preprocess(
            """
`define foo bar
`foo
`foo
"""
        )
        result.assert_no_log()

    def test_preprocess_include_directive_from_define(self):
        self.write_file("include.svh", "hello hey")
        result = self.preprocess(
            """\
`define inc "include.svh"
`include `inc""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("hello hey")
        result.assert_included_files([str(Path(self.output_path) / "include.svh")])

    def test_preprocess_include_directive_from_define_with_args(self):
        self.write_file("include.svh", "hello hey")
        result = self.preprocess(
            """\
`define inc(a) a
`include `inc("include.svh")""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("hello hey")
        result.assert_included_files([str(Path(self.output_path) / "include.svh")])

    def test_preprocess_macros_are_recursively_expanded(self):
        result = self.preprocess(
            """\
`define foo `bar
`define bar xyz
`foo
`define bar abc
`foo
""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("xyz\nabc\n")

    def test_ifndef_taken(self):
        result = self.preprocess(
            """\
`ifndef foo
taken
`endif
keep"""
        )
        result.assert_has_tokens("taken\nkeep")

    def test_ifdef_taken(self):
        result = self.preprocess(
            """\
`define foo
`ifdef foo
taken
`endif
keep"""
        )
        result.assert_has_tokens("taken\nkeep")

    def test_ifdef_else_taken(self):
        result = self.preprocess(
            """\
`define foo
`ifdef foo
taken
`else
else
`endif
keep"""
        )
        result.assert_has_tokens("taken\nkeep")

    def test_ifdef_not_taken(self):
        result = self.preprocess(
            """\
`ifdef foo
taken
`endif
keep"""
        )
        result.assert_has_tokens("keep")

    def test_ifdef_else_not_taken(self):
        result = self.preprocess(
            """\
`ifdef foo
taken
`else
else
`endif
keep"""
        )
        result.assert_has_tokens("else\nkeep")

    def test_ifdef_elsif_taken(self):
        result = self.preprocess(
            """\
`define foo
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep"""
        )
        result.assert_has_tokens("taken\nkeep")

    def test_ifdef_elsif_elseif_taken(self):
        result = self.preprocess(
            """\
`define bar
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep"""
        )
        result.assert_has_tokens("elsif_taken\nkeep")

    def test_ifdef_elsif_else_taken(self):
        result = self.preprocess(
            """\
`ifdef foo
taken
`elsif bar
elsif_taken
`else
else_taken
`endif
keep"""
        )
        result.assert_has_tokens("else_taken\nkeep")

    def test_nested_ifdef(self):
        result = self.preprocess(
            """\
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
keep"""
        )
        result.assert_has_tokens("outer_before\n" "inner_else\n" "inner_elsif\n" "outer_after\n" "keep")

    def test_preprocess_broken_define(self):
        result = self.preprocess("`define")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "Verilog `define without argument\n%s",
            "at fn.v line 1:\n" "`define\n" "~~~~~~~",
        )

    def test_preprocess_broken_define_first_argument(self):
        result = self.preprocess('`define "foo"')
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "Verilog `define invalid name\n%s",
            "at fn.v line 1:\n" '`define "foo"\n' "        ~~~~~",
        )

    def test_preprocess_broken_define_argument_list(self):
        result = self.preprocess("`define foo(")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" "`define foo(\n" "           ~",
        )

        result = self.preprocess("`define foo(a")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" "`define foo(a\n" "           ~",
        )

        result = self.preprocess("`define foo(a=")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" "`define foo(a=\n" "           ~",
        )

        result = self.preprocess("`define foo(a=b")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" "`define foo(a=b\n" "           ~",
        )

        result = self.preprocess("`define foo(a=)")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" "`define foo(a=)\n" "           ~",
        )

        result = self.preprocess('`define foo("a"')
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" '`define foo("a"\n' "           ~",
        )

        result = self.preprocess('`define foo("a"=')
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define argument list\n%s",
            "at fn.v line 1:\n" '`define foo("a"=\n' "           ~",
        )

    def test_preprocess_substitute_define_broken_args(self):
        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo(1 2)"""
        )
        result.assert_has_tokens("")

        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo"""
        )
        result.assert_has_tokens("")

        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo("""
        )
        result.assert_has_tokens("")

        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo(1"""
        )
        result.assert_has_tokens("")

    def test_preprocess_substitute_define_missing_argument(self):
        result = self.preprocess(
            """\
`define foo(arg1, arg2)arg1,arg2
`foo(1)"""
        )
        result.assert_has_tokens("")
        result.logger.warning.assert_called_once_with(
            "Missing value for argument arg2\n%s",
            "at fn.v line 2:\n" "`foo(1)\n" "~~~~",
        )

    def test_preprocess_substitute_define_too_many_argument(self):
        result = self.preprocess(
            """\
`define foo(arg1)arg1
`foo(1, 2)"""
        )
        result.assert_has_tokens("")
        result.logger.warning.assert_called_once_with(
            "Too many arguments got 2 expected 1\n%s",
            "at fn.v line 2:\n" "`foo(1, 2)\n" "~~~~",
        )

    def test_preprocess_substitute_define_with_nested_argument(self):
        result = self.preprocess("`define foo(arg1, arg2)arg1\n" "`foo([1, 2], 3)")
        self.assertFalse(result.logger.warning.called)
        result.assert_has_tokens("[1, 2]")

        result = self.preprocess("`define foo(arg1, arg2)arg1\n" "`foo({1, 2}, 3)")
        self.assertFalse(result.logger.warning.called)
        result.assert_has_tokens("{1, 2}")

        result = self.preprocess("`define foo(arg1, arg2)arg1\n" "`foo((1, 2), 3)")
        self.assertFalse(result.logger.warning.called)
        result.assert_has_tokens("(1, 2)")

        result = self.preprocess("`define foo(arg1)arg1\n" "`foo((1, 2))")
        self.assertFalse(result.logger.warning.called)
        result.assert_has_tokens("(1, 2)")

        # Not OK in simulator but we let the simulator
        # tell the user that this is a problem
        result = self.preprocess("`define foo(arg1)arg1\n" "`foo([1, 2)")
        self.assertFalse(result.logger.warning.called)
        result.assert_has_tokens("[1, 2")

    def test_preprocess_substitute_define_eof(self):
        result = self.preprocess("`define foo(arg1, arg2)arg1,arg2\n" "`foo(1 2")
        result.assert_has_tokens("")
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define actuals\n%s",
            "at fn.v line 2:\n" "`foo(1 2\n" "~~~~",
        )

        result = self.preprocess("`define foo(arg1, arg2)arg1,arg2\n" "`foo((1 2)")
        result.assert_has_tokens("")
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `define actuals\n%s",
            "at fn.v line 2:\n" "`foo((1 2)\n" "~~~~",
        )

    def test_substitute_undefined(self):
        result = self.preprocess("`foo")
        result.assert_has_tokens("")
        # Debug since there are many custon `names in tools
        result.logger.debug.assert_called_once_with("Verilog undefined name\n%s", "at fn.v line 1:\n" "`foo\n" "~~~~")

    def test_preprocess_include_directive_missing_file(self):
        result = self.preprocess('`include "missing.svh"', include_paths=[self.output_path])
        result.assert_has_tokens("")
        result.assert_included_files([])
        # Is debug message since there are so many builtin includes in tools
        result.logger.debug.assert_called_once_with(
            "Could not find `include file missing.svh\n%s",
            "at fn.v line 1:\n" '`include "missing.svh"\n' "         ~~~~~~~~~~~~~",
        )

    def test_preprocess_include_directive_missing_argument(self):
        result = self.preprocess("`include", include_paths=[self.output_path])
        result.assert_has_tokens("")
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `include argument\n%s",
            "at fn.v line 1:\n" "`include\n" "~~~~~~~~",
        )

    def test_preprocess_include_directive_bad_argument(self):
        self.write_file("include.svh", "hello hey")
        result = self.preprocess('`include foo "include.svh"', include_paths=[self.output_path])
        result.assert_has_tokens(' "include.svh"')
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "at fn.v line 1:\n" '`include foo "include.svh"\n' "         ~~~",
        )

    def test_preprocess_include_directive_from_define_bad_argument(self):
        result = self.preprocess(
            """\
`define inc foo
`include `inc
keep""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("\nkeep")
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "Verilog `include has bad argument\n%s",
            "from fn.v line 2:\n"
            "`include `inc\n"
            "         ~~~~\n"
            "at fn.v line 1:\n"
            "`define inc foo\n"
            "            ~~~",
        )

    def test_preprocess_include_directive_from_empty_define(self):
        result = self.preprocess(
            """\
`define inc
`include `inc
keep""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("\nkeep")
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "Verilog `include has bad argument, empty define `inc\n%s",
            "at fn.v line 2:\n" "`include `inc\n" "         ~~~~",
        )

    def test_preprocess_include_directive_from_define_not_defined(self):
        result = self.preprocess("`include `inc", include_paths=[self.output_path])
        result.assert_has_tokens("")
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "Verilog `include argument not defined\n%s",
            "at fn.v line 1:\n" "`include `inc\n" "         ~~~~",
        )

    def test_preprocess_error_in_include_file(self):
        self.write_file("include.svh", "`include foo")
        result = self.preprocess('\n\n`include "include.svh"', include_paths=[self.output_path])
        result.assert_has_tokens("\n\n")
        result.assert_included_files([str(Path(self.output_path) / "include.svh")])
        result.logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "from fn.v line 3:\n"
            '`include "include.svh"\n'
            "~~~~~~~~\n"
            "at include.svh line 1:\n"
            "`include foo\n"
            "         ~~~",
        )

    def test_preprocess_error_in_expanded_define(self):
        result = self.preprocess(
            """\
`define foo `include wrong
`foo
""",
            include_paths=[self.output_path],
        )
        result.assert_has_tokens("\n")
        result.assert_included_files([])
        result.logger.warning.assert_called_once_with(
            "Verilog `include bad argument\n%s",
            "from fn.v line 2:\n"
            "`foo\n"
            "~~~~\n"
            "at fn.v line 1:\n"
            "`define foo `include wrong\n"
            "                     ~~~~~",
        )

    def test_ifdef_eof(self):
        result = self.preprocess(
            """\
`ifdef foo
taken"""
        )
        result.assert_has_tokens("")
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `ifdef\n%s",
            "at fn.v line 1:\n" "`ifdef foo\n" "~~~~~~",
        )

    def test_ifdef_bad_argument(self):
        result = self.preprocess(
            """\
`ifdef "hello"
keep"""
        )
        result.assert_has_tokens("\nkeep")
        result.logger.warning.assert_called_once_with(
            "Bad argument to `ifdef\n%s",
            "at fn.v line 1:\n" '`ifdef "hello"\n' "       ~~~~~~~",
        )

    def test_elsif_bad_argument(self):
        result = self.preprocess(
            """\
`ifdef bar
`elsif "hello"
keep"""
        )
        result.assert_has_tokens("\nkeep")
        result.logger.warning.assert_called_once_with(
            "Bad argument to `elsif\n%s",
            "at fn.v line 2:\n" '`elsif "hello"\n' "       ~~~~~~~",
        )

    def test_undefineall(self):
        result = self.preprocess(
            """\
`define foo keep
`define bar keep2
`foo
`undefineall"""
        )
        result.assert_has_tokens("keep\n")
        result.assert_no_defines()

    def test_resetall(self):
        result = self.preprocess(
            """\
`define foo keep
`define bar keep2
`foo
`resetall"""
        )
        result.assert_has_tokens("keep\n")
        result.assert_no_defines()

    def test_undef(self):
        result = self.preprocess(
            """\
`define foo keep
`define bar keep2
`foo
`undef foo"""
        )
        result.assert_has_tokens("keep\n")
        result.assert_has_defines({"bar": Macro("bar", tokenize("keep2"))})

    def test_undef_eof(self):
        result = self.preprocess("`undef")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "EOF reached when parsing `undef\n%s",
            "at fn.v line 1:\n" "`undef\n" "~~~~~~",
        )

    def test_undef_bad_argument(self):
        result = self.preprocess('`undef "foo"')
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "Bad argument to `undef\n%s",
            "at fn.v line 1:\n" '`undef "foo"\n' "       ~~~~~",
        )

    def test_undef_not_defined(self):
        result = self.preprocess("`undef foo")
        result.assert_has_tokens("")
        result.assert_no_defines()
        result.logger.warning.assert_called_once_with(
            "`undef argument was not previously defined\n%s",
            "at fn.v line 1:\n" "`undef foo\n" "       ~~~",
        )

    def test_ignores_celldefine(self):
        result = self.preprocess("`celldefine`endcelldefine keep")
        result.assert_has_tokens(" keep")
        result.assert_no_log()

    def test_ignores_timescale(self):
        result = self.preprocess("`timescale 1 ns / 1 ps\nkeep")
        result.assert_has_tokens("\nkeep")
        result.assert_no_log()

    def test_ignores_default_nettype(self):
        result = self.preprocess("`default_nettype none\nkeep")
        result.assert_has_tokens("\nkeep")
        result.assert_no_log()

    def test_ignores_nounconnected_drive(self):
        result = self.preprocess("`nounconnected_drive keep")
        result.assert_has_tokens(" keep")
        result.assert_no_log()

    def test_ignores_protected_region(self):
        result = self.preprocess(
            """\
keep_before
`pragma protect begin_protected
ASDADSJAKSJDKSAJDISA
`pragma protect end_protected
keep_end"""
        )

        result.assert_has_tokens("keep_before\n\nkeep_end")
        result.assert_no_log()

    def preprocess(self, code, file_name="fn.v", include_paths=None):
        """
        Tokenize & Preprocess
        """
        tokenizer = VerilogTokenizer()
        preprocessor = VerilogPreprocessor(tokenizer)
        write_file(file_name, code)
        tokens = tokenizer.tokenize(code, file_name=file_name)
        defines = {}
        included_files = []
        with mock.patch("vunit.parsing.verilog.preprocess.LOGGER", autospec=True) as logger:
            tokens = preprocessor.preprocess(tokens, defines, include_paths, included_files)
        return PreprocessResult(
            self,
            tokens,
            defines,
            [fname for _, fname in included_files if fname is not None],
            logger,
        )

    def write_file(self, file_name, contents):
        """
        Write file with contents into output path
        """
        full_name = Path(self.output_path) / file_name
        full_path = full_name.parent
        if not full_path.exists():
            os.makedirs(str(full_path))
        with full_name.open("w") as fptr:
            fptr.write(contents)


class PreprocessResult(object):
    """
    Helper object to test preprocessing
    """

    def __init__(
        self,  # pylint: disable=too-many-arguments
        test,
        tokens,
        defines,
        included_files,
        logger,
    ):
        self.test = test
        self.tokens = tokens
        self.defines = defines
        self.included_files = included_files
        self.logger = logger

    def assert_has_tokens(self, code, noloc=True):
        """
        Check that tokens are the same as code
        """
        expected = tokenize(code)

        if noloc:
            self.test.assertEqual(strip_loc(self.tokens), strip_loc(expected))
        else:
            self.test.assertEqual(self.tokens, expected)
        return self

    def assert_no_defines(self):
        """
        Assert that there were no defines
        """
        self.test.assertEqual(self.defines, {})

    def assert_included_files(self, included_files):
        """
        Assert that these files where included
        """
        self.test.assertEqual(self.included_files, included_files)

    def assert_has_defines(self, defines):
        """
        Assert that these defines were made
        """
        self.test.assertEqual(self.defines.keys(), defines.keys())

        def macro_strip_loc(define):
            """
            Strip location information from a Macro
            """
            define.tokens = strip_loc(define.tokens)
            for key, value in define.defaults.items():
                define.defaults[key] = strip_loc(value)

        for key in self.defines:
            self.test.assertEqual(macro_strip_loc(self.defines[key]), macro_strip_loc(defines[key]))

    def assert_no_log(self):
        """
        Assert that no log call were made
        """
        self.test.assertEqual(self.logger.debug.mock_calls, [])
        self.test.assertEqual(self.logger.info.mock_calls, [])
        self.test.assertEqual(self.logger.warning.mock_calls, [])
        self.test.assertEqual(self.logger.error.mock_calls, [])


def tokenize(code, file_name="fn.v"):
    """
    Tokenize
    """
    tokenizer = VerilogTokenizer()
    return tokenizer.tokenize(code, file_name=file_name)


def strip_loc(tokens):
    """
    Strip location information
    """
    return [Token(token.kind, token.value, None) for token in tokens]
