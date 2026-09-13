-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- Tests of the python_pkg operations that are implemented by the Python
-- bridge and therefore only available for NVC and GHDL. The rest of the
-- package is tested by tb_python_pkg.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.python_context;

entity tb_python_pkg_bridge is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_python_pkg_bridge is
  constant std_logic_characters : string(1 to 9) := "UX01ZWLH-";
  constant group_error : string := "Only keyword arguments can be combined with & into a keyword argument group";
begin
  main : process
    constant golden : python_session_t := "golden";
    constant fixed_point : python_session_t := "fixed_point";
    variable arr, arr_b, result : integer_array_t;
    variable ptr : integer_vector_ptr_t;
    variable slv4 : std_logic_vector(3 downto 0);
    variable slv9_desc : std_logic_vector(8 downto 0) := "UX01ZWLH-";
    variable slv9_asc : std_logic_vector(0 to 8) := "UX01ZWLH-";
    variable result_vec9 : std_logic_vector(8 downto 0);
    variable s8 : signed(7 downto 0);
    variable u8 : unsigned(7 downto 0);
    variable u1 : unsigned(0 downto 0) := "1";
    variable u32 : unsigned(31 downto 0) := x"DEADBEEF";
    variable u64 : unsigned(63 downto 0) := (others => '1');
    variable u128 : unsigned(127 downto 0) := (others => '1');
    variable s64 : signed(63 downto 0) := x"8000000000000000";
    variable u_null : unsigned(0 downto 1);
    variable s_null : signed(0 downto 1);
    variable discard_int : integer;
    variable reals : real_vector(0 to 2);

    -- Evaluations whose result is thrown away after a mocked failure
    procedure discard(value : integer_vector) is
    begin
    end;

    procedure discard(value : real_vector) is
    begin
    end;

    function ends_with(value, suffix : string) return boolean is
      alias normalized : string(1 to value'length) is value;
    begin
      if value'length < suffix'length then
        return false;
      end if;
      return normalized(value'length - suffix'length + 1 to value'length) = suffix;
    end;

    -- Python function returning the error text that the bridge reports for a
    -- piece of source that fails. It is formatted the way the bridge formats
    -- it: the frames of the bridge itself are not part of the traceback.
    procedure define_error_helper is
    begin
      exec(
        "import linecache, traceback" +
        "def expected_error(source, name, is_eval=False):" +
        "    linecache.cache[name] = (len(source), None, source.splitlines(True), name)" +
        "    try:" +
        "        code = compile(source, name, 'eval' if is_eval else 'exec')" +
        "        eval(code) if is_eval else exec(code)" +
        "    except BaseException as exc:" +
        "        return ''.join(traceback.format_exception(type(exc), exc, exc.__traceback__.tb_next)).rstrip('\n')"
      );
    end;

    -- Python function showing the decimal value of its argument
    procedure define_as_str is
    begin
      exec("def as_str(x):" + "    return str(x)");
    end;

    -- Python function returning one of its keyword arguments
    procedure define_pick is
    begin
      exec("def pick(**kwargs):" + "    return kwargs['v']");
    end;

    -- Python function showing the source text of the arguments it is called with
    procedure define_describe is
    begin
      exec(
        "def describe(*args, **kwargs):" +
        "    return ', '.join([repr(a) for a in args] + [f'{k}={v!r}' for k, v in kwargs.items()])"
      );
    end;

    -- The same staged array used in two calls. The function modifies its
    -- argument in place but every use gets its own copy.
    procedure bump_twice(data : arg_t) is
    begin
      check_equal(integer'(call("bump", data)), 5);
      check_equal(integer'(call("bump", data)), 5);
    end;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      ---------------------------------------------------------------------
      -- exec and exec_file
      ---------------------------------------------------------------------
      if run("Test inline source") then
        exec("X = 6 * 7");
        exec("def get_x():" & LF & "    return X");
        check_equal(integer'(call("get_x")), 42);

      elsif run("Test multiline source with blank lines and indentation") then
        exec(
          "def double(x):" & LF &
          "" & LF &
          "    " & LF &
          "    return x * 2" & LF &
          ""
        );
        check_equal(integer'(call("double", arg(21))), 42);
        check_equal(integer'(call("double", arg(-5))), -10);

      elsif run("Test that + joins source lines") then
        check_equal(string'("a" + "b"), "a" & LF & "b");
        check_equal(string'("a" + "" + "b"), "a" & LF & LF & "b");
        exec(
          "def triple(x):" +
          "" +
          "    return x * 3"
        );
        check_equal(integer'(call("triple", arg(14))), 42);

      elsif run("Test that + on strings does not disturb numeric_std arithmetic") then
        check_equal(to_integer(unsigned'("0011") + "0001"), 4);
        check_equal(to_integer(signed'("1110") + signed'("0001")), -1);

      elsif run("Test persistent namespace across exec and call") then
        exec("COUNTER = 0");
        exec(
          "def inc():" +
          "    global COUNTER" +
          "    COUNTER += 1" +
          "    return COUNTER"
        );
        check_equal(integer'(call("inc")), 1);
        check_equal(integer'(call("inc")), 2);
        check_equal(integer'(call("inc")), 3);

      elsif run("Test executing a file with a relative file name") then
        exec_file("test/models/reference_model.py");
        check_equal(call_string("get_model_dir"), tb_path(runner_cfg) & "models");

      elsif run("Test executing a file with an absolute file name") then
        exec_file(tb_path(runner_cfg) & "models/reference_model.py");
        check_equal(call_string("get_model_dir"), tb_path(runner_cfg) & "models");

      elsif run("Test that __file__ is set during file execution and restored after") then
        exec_file("test/models/reference_model.py");
        check_equal(call_string("get_file_during_exec"), tb_path(runner_cfg) & "models/reference_model.py");
        exec("def after_file_absent():" + "    return '__file__' not in globals()");
        check_true(call_boolean("after_file_absent"));

      elsif run("Test sibling import without PYTHONPATH and that sys.path is restored") then
        exec("GAIN = 3");
        exec_file("test/models/importer.py");
        check_equal(integer'(call("scaled", arg(2))), 9); -- fir(2) = 3, 3 * GAIN(3) = 9
        check_false(call_boolean("dir_in_syspath"));

      elsif run("Test that re-executing a file executes it again") then
        exec_file("test/models/counter.py");
        exec_file("test/models/counter.py");
        check_equal(integer'(call("get_call_count")), 2);

      elsif run("Test that exec_file with a missing file fails") then
        -- The error message shows the path in the native format of the OS
        exec("import os" + "def native_repr(path):" + "    return repr(os.path.normpath(path))");
        mock(python_logger, failure);
        exec_file(tb_path(runner_cfg) & "models/does_not_exist.py");
        check_only_log(
          python_logger,
          "exec_file(""" & tb_path(runner_cfg) & "models/does_not_exist.py"") failed:" & LF &
          "FileNotFoundError: [Errno 2] No such file or directory: " &
          call_string("native_repr", arg(string'(tb_path(runner_cfg) & "models/does_not_exist.py"))),
          failure
        );
        unmock(python_logger);

      elsif run("Test that a Python exception with traceback logs a failure") then
        define_error_helper;
        mock(python_logger, failure);
        exec("raise ValueError('boom')");
        check_only_log(
          python_logger,
          "exec failed:" & LF &
          call_string(
            "expected_error", arg(string'("raise ValueError('boom')")), arg(string'("<exec #2>"))
          ),
          failure
        );
        unmock(python_logger);

      elsif run("Test that operations work after python_cleanup") then
        exec("cleanup_marker = 1");
        python_cleanup;
        exec("cleanup_marker = cleanup_marker + 1");
        check_equal(eval_integer("cleanup_marker"), 2);

      elsif run("Test that the run script path is known to the testbench") then
        check_true(ends_with(run_script_path(runner_cfg), "/run.py"));

      ---------------------------------------------------------------------
      -- Result types
      ---------------------------------------------------------------------
      elsif run("Test that the bridge operations keep the other forms unambiguous") then
        -- The bridge operations add eval, call, arg and kwarg overloads but
        -- must not make any other form ambiguous, not even a string literal
        -- argument or an eval whose type comes from the context.
        check_equal(eval("17"), 17);
        check_equal(eval("3.40282346e38"), 3.40282346e38);
        check_equal(eval("''"), string'(""));
        check(eval(to_py_list_str(integer_vector'(-1, 0, 1))) = integer_vector'(-1, 0, 1));
        check(eval(to_py_list_str(real_vector'(1.5, -0.25))) = real_vector'(1.5, -0.25));
        ptr := eval(to_py_list_str(integer_vector'(0 => 17)));
        check_equal(get(ptr, 0), 17);
        reals := eval("[1.5, -3.6, 9.1]");
        check_equal(reals(1), -3.6);
        check_equal(call("len", arg("Hello")), 5);
        check_equal(call("max", arg(2.1), arg(1.1)), 2.1);
        check_equal(call("int", arg(true)), 1);
        check_equal(call("round", arg(3.14159), kwarg("ndigits", 3)), 3.142);
        exec("l = [1]");
        call("l.append", arg(2));
        check_equal(eval_integer("l[1]"), 2);
        check_true(eval("'Yes'") = string'("Yes"));

      elsif run("Test eval of a condition") then
        -- eval_boolean makes the result of eval usable as a condition
        exec("threshold = 5");
        if eval("True") then
          check_true(true);
        else
          check_failed("eval(""True"") must be true");
        end if;

        if eval("threshold > 10") then
          check_failed("eval(""threshold > 10"") must be false");
        end if;

      elsif run("Test call without arguments") then
        exec("def answer():" + "    return 42");
        check_equal(integer'(call("answer")), 42);

      elsif run("Test integer round trip including bounds") then
        exec("def identity(x):" + "    return x");
        check_equal(integer'(call("identity", arg(0))), 0);
        check_equal(integer'(call("identity", arg(123456))), 123456);
        check_equal(integer'(call("identity", arg(integer'low))), integer'low);
        check_equal(integer'(call("identity", arg(integer'high))), integer'high);

      elsif run("Test real round trip") then
        exec("def identity(x):" + "    return x");
        check_equal(real'(call("identity", arg(0.0))), 0.0);
        check_equal(real'(call("identity", arg(3.5))), 3.5);
        check_equal(real'(call("identity", arg(-2.25))), -2.25);
        check_equal(eval_real("1 / 3"), 1.0 / 3.0);

      elsif run("Test that eval of real rejects an int") then
        mock(python_logger, failure);
        check_equal(eval_real("1"), 0.0);
        check_only_log(
          python_logger,
          "eval(""1"") failed:" & LF &
          "TypeError: Cannot convert Python int (1) to VHDL real; expected float",
          failure
        );
        unmock(python_logger);

      elsif run("Test boolean round trip") then
        exec("def identity(x):" + "    return x");
        check_true(call_boolean("identity", arg(true)));
        check_false(call_boolean("identity", arg(false)));
        check_true(eval_boolean("1 < 2"));

      elsif run("Test string round trip including non-ASCII") then
        exec("def identity(x):" + "    return x");
        check_equal(call_string("identity", arg(string'(""))), string'(""));
        check_equal(call_string("identity", arg(string'("hello"))), string'("hello"));
        check_equal(call_string("identity", arg(string'("café å"))), string'("café å"));

      elsif run("Test std_logic round trip of all 9 states") then
        exec("def identity(x):" + "    return x");
        for idx in std_logic_characters'range loop
          check_equal(
            call_std_logic("identity", arg(string'(1 => std_logic_characters(idx)))),
            std_logic'val(idx - 1)
          );
        end loop;

      elsif run("Test std_logic_vector round trip with descending range") then
        exec("def identity(x):" + "    return x");
        result_vec9 := call_std_logic_vector("identity", arg(to_string(slv9_desc)));
        check_equal(result_vec9, slv9_desc);

      elsif run("Test std_logic_vector round trip with ascending range") then
        exec("def identity(x):" + "    return x");
        call_std_logic_vector("identity", result_vec9, arg(to_string(slv9_asc)));
        check_equal(result_vec9, slv9_asc);

      elsif run("Test signed and unsigned procedure results including exact bounds") then
        exec("def identity(x):" + "    return x");

        call_signed("identity", s8, arg(-128));
        check_equal(s8, to_signed(-128, 8));

        call_signed("identity", s8, arg(127));
        check_equal(s8, to_signed(127, 8));

        call_unsigned("identity", u8, arg(0));
        check_equal(u8, to_unsigned(0, 8));

        call_unsigned("identity", u8, arg(255));
        check_equal(u8, to_unsigned(255, 8));

        eval_signed("-1", s8);
        check_equal(s8, to_signed(-1, 8));

        eval_unsigned("2 ** 8 - 1", u8);
        check_equal(u8, to_unsigned(255, 8));

      elsif run("Test integer_vector and real_vector results") then
        exec("def identity(x):" + "    return x");
        reals := call_real_vector("identity", arg(real_vector'(1.5, -0.25, 0.0)));
        check_equal(reals(0), 1.5);
        check_equal(reals(1), -0.25);
        check_equal(reals(2), 0.0);

        ptr := call_integer_vector_ptr("identity", arg(integer_vector'(-1, 0, 1)));
        check_equal(length(ptr), 3);
        check_equal(get(ptr, 0), -1);
        check_equal(get(ptr, 2), 1);

      elsif run("Test that eval of integer_vector is strict about element types") then
        mock(python_logger, failure);
        discard(eval_integer_vector("[1, 2.0]"));
        check_log(
          python_logger,
          "eval(""[1, 2.0]"") failed:" & LF &
          "TypeError: Cannot convert element 1 of the Python list, a float (2.0), " &
          "to a VHDL integer; expected int",
          failure
        );
        discard(eval_integer_vector("[True]"));
        check_log(
          python_logger,
          "eval(""[True]"") failed:" & LF &
          "TypeError: Cannot convert element 0 of the Python list, a bool (True), " &
          "to a VHDL integer; expected int",
          failure
        );
        discard(eval_integer_vector("17"));
        check_only_log(
          python_logger,
          "eval(""17"") failed:" & LF &
          "TypeError: Cannot convert Python int (17) to VHDL integer_vector; expected a list or tuple",
          failure
        );
        unmock(python_logger);

      elsif run("Test that eval of real_vector is strict about element types") then
        reals := eval_real_vector("(1.5, -0.25, 0.0)");
        check_equal(reals(1), -0.25);

        mock(python_logger, failure);
        discard(eval_real_vector("[1.0, 2]"));
        check_log(
          python_logger,
          "eval(""[1.0, 2]"") failed:" & LF &
          "TypeError: Cannot convert element 1 of the Python list, a int (2), to a VHDL real; expected float",
          failure
        );
        discard(eval_real_vector("[True]"));
        check_only_log(
          python_logger,
          "eval(""[True]"") failed:" & LF &
          "TypeError: Cannot convert element 0 of the Python list, a bool (True), to a VHDL real; expected float",
          failure
        );
        unmock(python_logger);

      elsif run("Test that a wrong return type fails") then
        exec("def returns_none():" + "    return None");
        mock(python_logger, failure);
        discard_int := call("returns_none");
        check_only_log(
          python_logger,
          "eval(""returns_none()"") failed:" & LF &
          "TypeError: Cannot convert Python NoneType (None) to VHDL integer; expected int",
          failure
        );
        unmock(python_logger);

      elsif run("Test that integer overflow fails") then
        exec("def too_big():" + "    return 2**31");
        mock(python_logger, failure);
        discard_int := call("too_big");
        check_only_log(
          python_logger,
          "eval(""too_big()"") failed:" & LF &
          "OverflowError: 2147483648 is outside the range of VHDL integer (-2147483648 to 2147483647)",
          failure
        );
        unmock(python_logger);

      elsif run("Test that signed overflow in a procedure result fails") then
        exec("def identity(x):" + "    return x");
        mock(python_logger, failure);
        call_signed("identity", s8, arg(200));
        check_only_log(
          python_logger,
          "eval(""identity(200)"") failed:" & LF &
          "OverflowError: 200 does not fit in a 8 bit signed (-128 to 127)",
          failure
        );
        unmock(python_logger);

      elsif run("Test that unsigned overflow in a procedure result fails") then
        exec("def identity(x):" + "    return x");
        mock(python_logger, failure);
        call_unsigned("identity", u8, arg(-1));
        check_only_log(
          python_logger,
          "eval(""identity(-1)"") failed:" & LF &
          "OverflowError: -1 does not fit in a 8 bit unsigned (0 to 255)",
          failure
        );
        unmock(python_logger);

      elsif run("Test that a std_logic_vector length mismatch in a procedure result fails") then
        exec("def wrong_length_bits():" + "    return '01011'");
        mock(python_logger, failure);
        call_std_logic_vector("wrong_length_bits", slv4);
        check_only_log(
          python_logger,
          "eval(""wrong_length_bits()"") failed:" & LF &
          "ValueError: Got 5 std_logic values but the VHDL result has length 4",
          failure
        );
        unmock(python_logger);

      elsif run("Test that an undefined function fails") then
        define_error_helper;
        mock(python_logger, failure);
        discard_int := call("no_such_function");
        check_only_log(
          python_logger,
          "eval(""no_such_function()"") failed:" & LF &
          call_string(
            "expected_error", arg(string'("no_such_function()")), arg(string'("<eval #2>")), arg(true)
          ),
          failure
        );
        unmock(python_logger);

      ---------------------------------------------------------------------
      -- Argument values
      ---------------------------------------------------------------------
      elsif run("Test arg and kwarg of real_vector and integer_vector_ptr values") then
        define_describe;
        -- An aggregate needs a qualified expression to select the overload
        check_equal(call_string("describe", arg(real_vector'(1.5, -0.25))), "[1.5, -0.25]");
        check_equal(call_string("describe", kwarg("v", real_vector'(0 => 0.5))), "v=[0.5]");
        ptr := new_integer_vector_ptr(3);
        for idx in 0 to 2 loop
          set(ptr, idx, idx - 1);
        end loop;
        check_equal(call_string("describe", arg(ptr)), "[-1, 0, 1]");
        check_equal(call_string("describe", kwarg("v", ptr)), "v=[-1, 0, 1]");

      elsif run("Test std_logic_vector, signed and unsigned arguments") then
        -- There are no arg overloads for these types, which would make a
        -- string literal argument ambiguous. They are passed as a string, as
        -- an integer or through arg_unsigned/arg_signed instead.
        define_describe;
        check_equal(call_string("describe", arg(to_string(slv9_desc))), "'UX01ZWLH-'");
        check_equal(call_string("describe", kwarg("v", to_string(std_logic_vector'("10XZ")))), "v='10XZ'");
        s8 := to_signed(-128, 8);
        u8 := to_unsigned(255, 8);
        check_equal(call_string("describe", arg(to_integer(s8)), arg(to_integer(u8))), "-128, 255");
        exec("def identity(x):" + "    return x");
        check_equal(integer'(call("identity", arg(to_integer(s8)))), -128);
        check_equal(integer'(call("identity", arg(to_integer(u8)))), 255);

      elsif run("Test arg and kwarg of integer_array_t values") then
        exec("def total(*args, **kwargs):" + "    return int(sum(a.sum() for a in list(args) + list(kwargs.values())))");
        arr := new_1d(length => 4, bit_width => 16, is_signed => true);
        for idx in 0 to 3 loop
          set(arr, idx, idx + 1);
        end loop;
        arr_b := new_1d(length => 2, bit_width => 8, is_signed => false);
        set(arr_b, 0, 10);
        set(arr_b, 1, 20);
        check_equal(integer'(call("total", arg(arr), kwarg("data", arr_b))), 40);

      elsif run("Test positional and keyword arguments together") then
        exec("def scale(x, gain=1, offset=0):" + "    return x * gain + offset");
        check_equal(integer'(call("scale", arg(5), kwarg("gain", 3), kwarg("offset", 1))), 16);
        check_equal(integer'(call("scale", arg(5), kwarg("offset", 2))), 7);
        check_equal(integer'(call("scale", arg(5))), 5);

      elsif run("Test that a staged array can be used in several calls") then
        exec("def bump(data):" + "    data += 1" + "    return int(data.sum())");
        arr := new_1d(2);
        set(arr, 0, 1);
        set(arr, 1, 2);
        bump_twice(arg(arr));

      ---------------------------------------------------------------------
      -- Keyword argument groups
      ---------------------------------------------------------------------
      elsif run("Test a keyword argument group") then
        define_describe;
        -- The group is a single argument and can be in any of the 10 slots
        check_equal(call_string("describe", kwarg("a", 1) & kwarg("b", 2)), "a=1, b=2");
        check_equal(
          call_string("describe", arg(1), arg(string'("x")), kwarg("a", 1) & kwarg("b", 2) & kwarg("c", 3)),
          "1, 'x', a=1, b=2, c=3"
        );
        check_equal(
          call_string("describe", (kwarg("a", 1) & kwarg("b", 2)) & (kwarg("c", 3) & kwarg("d", 4))),
          "a=1, b=2, c=3, d=4"
        );

      elsif run("Test 25 keyword arguments in one group") then
        exec("def total(**kwargs):" + "    return sum(kwargs.values())");
        check_equal(
          integer'(call(
            "total",
            kwarg("a01", 1) & kwarg("a02", 2) & kwarg("a03", 3) & kwarg("a04", 4) & kwarg("a05", 5) &
            kwarg("a06", 6) & kwarg("a07", 7) & kwarg("a08", 8) & kwarg("a09", 9) & kwarg("a10", 10) &
            kwarg("a11", 11) & kwarg("a12", 12) & kwarg("a13", 13) & kwarg("a14", 14) & kwarg("a15", 15) &
            kwarg("a16", 16) & kwarg("a17", 17) & kwarg("a18", 18) & kwarg("a19", 19) & kwarg("a20", 20) &
            kwarg("a21", 21) & kwarg("a22", 22) & kwarg("a23", 23) & kwarg("a24", 24) & kwarg("a25", 25)
          )),
          325
        );

      elsif run("Test that null_arg is the identity of a keyword argument group") then
        define_describe;
        check_equal(call_string("describe", null_arg & kwarg("a", 1)), "a=1");
        check_equal(call_string("describe", kwarg("a", 1) & null_arg), "a=1");
        check_equal(call_string("describe", null_arg & null_arg), "");
        check_equal(call_string("describe", null_arg & (kwarg("a", 1) & kwarg("b", 2)) & null_arg), "a=1, b=2");

      elsif run("Test a keyword argument group with the result types of call") then
        define_pick;
        check_equal(integer'(call("pick", kwarg("v", 7) & kwarg("w", 0))), 7);
        check_equal(real'(call("pick", kwarg("v", 1.5) & kwarg("w", 0))), 1.5);
        check_equal(call_string("pick", kwarg("v", string'("x")) & kwarg("w", 0)), "x");
        check_true(call_boolean("pick", kwarg("v", true) & kwarg("w", 0)));
        check(
          integer_vector'(call("pick", kwarg("v", integer_vector'(1, 2)) & kwarg("w", 0))) = integer_vector'(1, 2)
        );

        exec("recorded = 0" + "def record(**kwargs):" + "    global recorded" + "    recorded = kwargs['v']");
        call("record", kwarg("v", 42) & kwarg("w", 0));
        check_equal(eval_integer("recorded"), 42);

      elsif run("Test that a repeated keyword in a group is a Python error") then
        define_error_helper;
        mock(python_logger, failure);
        check_equal(call_string("describe", kwarg("a", 1) & kwarg("a", 2)), "");
        check_only_log(
          python_logger,
          "eval(""describe(**dict(a=1, a=2))"") failed:" & LF &
          call_string(
            "expected_error", arg(string'("describe(**dict(a=1, a=2))")), arg(string'("<eval #1>")), arg(true)
          ),
          failure
        );
        unmock(python_logger);

      elsif run("Test that a keyword argument group before a positional argument is a Python error") then
        define_error_helper;
        mock(python_logger, failure);
        check_equal(call_string("describe", kwarg("a", 1) & kwarg("b", 2), arg(3)), "");
        check_only_log(
          python_logger,
          "eval(""describe(**dict(a=1, b=2), 3)"") failed:" & LF &
          call_string(
            "expected_error", arg(string'("describe(**dict(a=1, b=2), 3)")), arg(string'("<eval #1>")), arg(true)
          ),
          failure
        );
        unmock(python_logger);

      elsif run("Test that combining a positional argument with & fails") then
        define_describe;
        mock(python_logger, failure);
        check_equal(call_string("describe", arg(1) & kwarg("a", 2)), "");
        check_log(python_logger, group_error, failure);
        check_equal(call_string("describe", kwarg("a", 2) & arg(1)), "");
        check_log(python_logger, group_error, failure);
        check_equal(call_string("describe", (kwarg("a", 1) & kwarg("b", 2)) & arg(3)), "");
        check_only_log(python_logger, group_error, failure);
        unmock(python_logger);

      ---------------------------------------------------------------------
      -- Wide and std_logic argument values
      ---------------------------------------------------------------------
      elsif run("Test unsigned arguments of any width") then
        define_as_str;
        check_equal(call_string("as_str", arg_unsigned(u1)), "1");
        check_equal(call_string("as_str", arg_unsigned(unsigned'("0"))), "0");
        check_equal(call_string("as_str", arg_unsigned(unsigned'(x"FF"))), "255");
        check_equal(call_string("as_str", arg_unsigned(u32)), "3735928559");
        check_equal(call_string("as_str", arg_unsigned(u64)), "18446744073709551615");
        check_equal(
          call_string("as_str", arg_unsigned(u128)), "340282366920938463463374607431768211455"
        );
        check_equal(call_string("as_str", arg_unsigned(u_null)), "0");

        -- The value survives a round trip through Python
        exec("def identity(x):" + "    return x");
        call_unsigned("identity", u32, arg_unsigned(u32));
        check_equal(u32, unsigned'(x"DEADBEEF"));

      elsif run("Test signed arguments including the lowest value") then
        define_as_str;
        check_equal(call_string("as_str", arg_signed(signed'(x"7F"))), "127");
        check_equal(call_string("as_str", arg_signed(signed'("0"))), "0");
        check_equal(call_string("as_str", arg_signed(signed'("1"))), "-1");
        check_equal(call_string("as_str", arg_signed(to_signed(-1, 8))), "-1");
        check_equal(call_string("as_str", arg_signed(to_signed(-128, 8))), "-128");
        check_equal(call_string("as_str", arg_signed(s64)), "-9223372036854775808");
        check_equal(call_string("as_str", arg_signed(s_null)), "0");

        exec("def identity(x):" + "    return x");
        call_signed("identity", s8, arg_signed(to_signed(-128, 8)));
        check_equal(s8, to_signed(-128, 8));

      elsif run("Test that H and L are read as 1 and 0 in argument values") then
        define_as_str;
        check_equal(call_string("as_str", arg_unsigned(unsigned'("HLHLHLHL"))), "170");
        check_equal(call_string("as_str", arg_signed(signed'("HLHL"))), "-6");
        define_describe;
        check_equal(call_string("describe", arg('H'), arg('L')), "True, False");

      elsif run("Test that a metavalue in an unsigned or signed argument fails") then
        define_describe;
        mock(python_logger, failure);
        check_equal(call_string("describe", arg_unsigned(unsigned'("1010X010"))), "");
        check_log(
          python_logger, "arg_unsigned cannot convert ""1010X010""; the value has metavalues", failure
        );
        check_equal(call_string("describe", arg_signed(signed'("10Z0"))), "");
        check_log(python_logger, "arg_signed cannot convert ""10Z0""; the value has metavalues", failure);
        check_equal(call_string("describe", kwarg_unsigned("v", unsigned'("U"))), "");
        check_only_log(
          python_logger, "kwarg_unsigned cannot convert ""U""; the value has metavalues", failure
        );
        unmock(python_logger);

      elsif run("Test std_logic arguments") then
        define_describe;
        check_equal(call_string("describe", arg('1'), arg('0')), "True, False");
        check_equal(call_string("describe", kwarg("v", '1'), kwarg("w", 'L')), "v=True, w=False");

      elsif run("Test that a metavalue std_logic argument fails") then
        define_describe;
        mock(python_logger, failure);
        check_equal(call_string("describe", arg('X')), "");
        check_log(python_logger, "arg cannot convert 'X'; expected '0', '1', 'L' or 'H'", failure);
        check_equal(call_string("describe", kwarg("v", '-')), "");
        check_only_log(python_logger, "kwarg cannot convert '-'; expected '0', '1', 'L' or 'H'", failure);
        unmock(python_logger);

      elsif run("Test keyword forms of the typed argument values") then
        define_describe;
        check_equal(call_string("describe", kwarg_unsigned("v", unsigned'(x"FF"))), "v=255");
        check_equal(call_string("describe", kwarg_signed("v", to_signed(-3, 4))), "v=-3");
        check_equal(
          call_string("describe", kwarg_unsigned("v", u64) & kwarg_signed("w", s64)),
          "v=18446744073709551615, w=-9223372036854775808"
        );

      ---------------------------------------------------------------------
      -- integer_array_t
      ---------------------------------------------------------------------
      elsif run("Test that a 2D array preserves axis orientation, get(a, x, y) is row y column x") then
        arr := new_2d(width => 3, height => 2, bit_width => 16, is_signed => false);
        for y in 0 to 1 loop
          for x in 0 to 2 loop
            set(arr, x, y, y * 10 + x);
          end loop;
        end loop;
        exec(
          "def orientation_ok(a):" +
          "    return bool(a[0, 1] == 1 and a[1, 2] == 12 and a.shape == (2, 3))"
        );
        check_true(call_boolean("orientation_ok", arg(arr)));

      elsif run("Test that a 3D array preserves axis orientation, get(a, x, y, z) is row y column x plane z") then
        arr := new_3d(width => 3, height => 2, depth => 4, bit_width => 16, is_signed => false);
        for y in 0 to 1 loop
          for x in 0 to 2 loop
            for z in 0 to 3 loop
              set(arr, x, y, z, y * 100 + x * 10 + z);
            end loop;
          end loop;
        end loop;
        exec(
          "def orientation_ok3(a):" +
          "    return bool(a[0, 1, 2] == 12 and a[1, 2, 3] == 123 and a.shape == (2, 3, 4))"
        );
        check_true(call_boolean("orientation_ok3", arg(arr)));

      elsif run("Test that returned 2D and 3D arrays preserve axis orientation") then
        exec(
          "import numpy as np" +
          "def make2():" +
          "    return np.array([[10 * y + x for x in range(3)] for y in range(2)], dtype=np.int16)" +
          "def make3():" +
          "    return np.fromfunction(lambda y, x, z: 100 * y + 10 * x + z, (2, 3, 4), dtype=int)"
        );
        result := call_integer_array("make2");
        check_equal(width(result), 3);
        check_equal(height(result), 2);
        check_equal(depth(result), 1);
        check_equal(bit_width(result), 16);
        check_true(is_signed(result));
        for y in 0 to 1 loop
          for x in 0 to 2 loop
            check_equal(get(result, x, y), 10 * y + x);
          end loop;
        end loop;

        result := call_integer_array("make3");
        check_equal(width(result), 3);
        check_equal(height(result), 2);
        check_equal(depth(result), 4);
        for y in 0 to 1 loop
          for x in 0 to 2 loop
            for z in 0 to 3 loop
              check_equal(get(result, x, y, z), 100 * y + 10 * x + z);
            end loop;
          end loop;
        end loop;

      elsif run("Test that metadata is preserved when returning the same array argument") then
        arr := new_1d(length => 4, bit_width => 12, is_signed => true);
        set(arr, 0, -2048);
        set(arr, 1, -1);
        set(arr, 2, 0);
        set(arr, 3, 2047);
        exec("def identity(a):" + "    return a");
        result := call_integer_array("identity", arg(arr));
        check_equal(bit_width(result), 12);
        check_true(is_signed(result));
        check_equal(length(result), 4);
        for idx in 0 to 3 loop
          check_equal(get(result, idx), get(arr, idx));
        end loop;

      elsif run("Test that metadata is derived from dtype for a newly created array") then
        arr := new_1d(length => 4, bit_width => 10, is_signed => false);
        set(arr, 0, 0);
        set(arr, 1, 1);
        set(arr, 2, 500);
        set(arr, 3, 1023);
        exec(
          "import numpy as np" +
          "def to_uint8(a):" +
          "    return (a % 256).astype(np.uint8)"
        );
        result := call_integer_array("to_uint8", arg(arr));
        check_equal(bit_width(result), 8);
        check_false(is_signed(result));
        check_equal(length(result), 4);
        check_equal(get(result, 0), 0);
        check_equal(get(result, 1), 1);
        check_equal(get(result, 2), 500 mod 256);
        check_equal(get(result, 3), 1023 mod 256);

      elsif run("Test call with several array arguments") then
        exec(
          "def sum_arrays(*args):" +
          "    return int(sum(int(a.sum()) for a in args))"
        );
        check_equal(integer'(call("sum_arrays")), 0);
        arr := new_1d(length => 3, bit_width => 8, is_signed => false);
        set(arr, 0, 1);
        set(arr, 1, 2);
        set(arr, 2, 3);
        check_equal(integer'(call("sum_arrays", arg(arr))), 6);
        arr_b := new_1d(length => 2, bit_width => 8, is_signed => false);
        set(arr_b, 0, 10);
        set(arr_b, 1, 20);
        check_equal(integer'(call("sum_arrays", arg(arr), arg(arr_b), arg(arr))), 42);

      elsif run("Test returning a new array with a different shape") then
        arr := new_2d(width => 3, height => 2, bit_width => 16, is_signed => false);
        for y in 0 to 1 loop
          for x in 0 to 2 loop
            set(arr, x, y, y * 10 + x);
          end loop;
        end loop;
        exec("def flatten(a):" + "    return a.reshape(-1)");
        result := call_integer_array("flatten", arg(arr));
        check_equal(length(result), 6);
        check_equal(bit_width(result), 32);
        check_true(is_signed(result));
        check_equal(get(result, 0), 0);
        check_equal(get(result, 1), 1);
        check_equal(get(result, 2), 2);
        check_equal(get(result, 3), 10);
        check_equal(get(result, 4), 11);
        check_equal(get(result, 5), 12);

      elsif run("Test null array round trip") then
        arr := new_1d(length => 0, bit_width => 16, is_signed => false);
        exec("def identity(a):" + "    return a");
        result := call_integer_array("identity", arg(arr));
        check_equal(length(result), 0);

      ---------------------------------------------------------------------
      -- Sessions
      ---------------------------------------------------------------------
      elsif run("Test that sessions have separate namespaces") then
        exec("x = 1" + "def get_x(): return x", golden);
        exec("x = 2" + "def get_x(): return x", fixed_point);
        exec("x = 3" + "def get_x(): return x");
        check_equal(integer'(call("get_x", session => golden)), 1);
        check_equal(integer'(call("get_x", session => fixed_point)), 2);
        check_equal(integer'(call("get_x")), 3);
        check_equal(integer'(call("get_x", session => default_session)), 3);
        check_equal(eval_integer("x", golden), 1);

      elsif run("Test that a name defined in another session is not visible") then
        define_error_helper;
        exec("def only_in_golden(): return 1", golden);
        mock(python_logger, failure);
        discard_int := call("only_in_golden", session => fixed_point);
        check_only_log(
          python_logger,
          "eval(""only_in_golden()"", session => ""fixed_point"") failed:" & LF &
          call_string(
            "expected_error", arg(string'("only_in_golden()")), arg(string'("<eval fixed_point #2>")), arg(true)
          ),
          failure
        );
        unmock(python_logger);

      elsif run("Test executing a file in different sessions") then
        exec_file("test/models/counter.py", golden);
        exec_file("test/models/counter.py", golden);
        exec_file("test/models/counter.py", fixed_point);
        check_equal(integer'(call("get_call_count", session => golden)), 2);
        check_equal(integer'(call("get_call_count", session => fixed_point)), 1);

      elsif run("Test arrays and procedure results in a session") then
        exec("def double(a): return a * 2", golden);
        arr := new_1d(3);
        for idx in 0 to 2 loop
          set(arr, idx, idx + 1);
        end loop;
        result := call_integer_array("double", arg(arr), session => golden);
        check_equal(get(result, 2), 6);

        exec("def identity(x): return x", golden);
        call_unsigned("identity", u8, arg(42), session => golden);
        check_equal(to_integer(u8), 42);

      elsif run("Test that imported modules are shared between sessions") then
        exec("import math" + "math.vunit_marker = 7", golden);
        exec("import math" + "def get_marker(): return math.vunit_marker", fixed_point);
        check_equal(integer'(call("get_marker", session => fixed_point)), 7);

      elsif run("Test error context names the session") then
        define_error_helper;
        mock(python_logger, failure);
        exec("1 / 0", golden);
        check_only_log(
          python_logger,
          "exec(session => ""golden"") failed:" & LF &
          call_string("expected_error", arg(string'("1 / 0")), arg(string'("<exec golden #2>"))),
          failure
        );
        unmock(python_logger);

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
