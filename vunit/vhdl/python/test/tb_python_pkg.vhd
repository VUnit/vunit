-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
-- Keep this as an add-on while developing
-- but eventually I think it should be included
-- by default for supporting simulators
context vunit_lib.python_context;

library ieee;
use ieee.math_real.all;

entity tb_python_pkg is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_python_pkg is
  constant integer_range : string :=
    "(" & integer'image(integer'low) & " to " & integer'image(integer'high) & ")";
begin
  test_runner : process
    constant empty_integer_vector : integer_vector(0 downto 1) := (others => 0);
    constant empty_real_vector : real_vector(0 downto 1) := (others => 0.0);
    constant test_real_vector : real_vector := (-3.4028234664e38, -1.9, 0.0, 1.1, -3.4028234664e38);

    variable vhdl_int : integer;
    variable vhdl_real : real;
    variable vhdl_real_vector : real_vector(test_real_vector'range);
    variable vhdl_integer_vector_ptr : integer_vector_ptr_t;
    variable vhdl_integer_vector : integer_vector(0 to 3);
    variable arg_value2 : arg_t(name(1 to 2), value(1 to 2));
    variable arg_value4 : arg_t(name(1 to 2), value(1 to 4));
    variable arg_value22 : arg_t(name(1 to 2), value(1 to 22));

    procedure print(a : arg_t) is
    begin
      print(a.name);
      print(a.value);
    end;

    -- Python function returning the error text that the Python interface
    -- reports for a piece of source that fails. It is formatted the way the
    -- interface formats it: its own frames are not part of the traceback.
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

  begin
    test_runner_setup(runner, runner_cfg);

    show(display_handler, debug);

    while test_suite loop
    ---------------------------------------------------------------------
    -- Test eval of different types
    ---------------------------------------------------------------------
      if run("Test eval of integer expression") then
        check_equal(eval("17"), 17);
        check_equal(eval("2**31 - 1"), integer'high);
        check_equal(eval("-2**31"), integer'low);

      elsif run("Test eval of integer with overflow from Python to C") then
        mock(python_logger, failure);
        vhdl_int := eval("2**63");
        check_only_log(
          python_logger,
          "eval(""2**63"") failed:" & LF &
          "OverflowError: 9223372036854775808 is outside the range of VHDL integer " & integer_range,
          failure
        );
        unmock(python_logger);

      elsif run("Test eval of integer with underflow from Python to C") then
        mock(python_logger, failure);
        vhdl_int := eval("-2**63 - 1");
        check_only_log(
          python_logger,
          "eval(""-2**63 - 1"") failed:" & LF &
          "OverflowError: -9223372036854775809 is outside the range of VHDL integer " & integer_range,
          failure
        );
        unmock(python_logger);

      elsif run("Test eval of integer with overflow from C to VHDL") then
        mock(python_logger, failure);
        vhdl_int := eval("2**31");
        check_only_log(
          python_logger,
          "eval(""2**31"") failed:" & LF &
          "OverflowError: 2147483648 is outside the range of VHDL integer " & integer_range,
          failure
        );
        unmock(python_logger);

      elsif run("Test eval of integer with underflow from C to VHDL") then
        mock(python_logger, failure);
        vhdl_int := eval("-2**31 - 1");
        check_only_log(
          python_logger,
          "eval(""-2**31 - 1"") failed:" & LF &
          "OverflowError: -2147483649 is outside the range of VHDL integer " & integer_range,
          failure
        );
        unmock(python_logger);

      elsif run("Test eval of real expression") then
        check_equal(eval("3.40282346e38"), 3.40282346e38);
        check_equal(eval("1.1754943508e-38"), 1.1754943508e-38);
        check_equal(eval("-3.4028e38"), -3.4028e38);
        check_equal(eval("-1.1754943508e-38"), -1.1754943508e-38);

      elsif run("Test eval of real with overflow from C to VHDL") then
        -- VHDL real is double precision where the Python bridge implements
        -- the API, so any finite Python float is in range
        check_equal(eval("1.0e300"), 1.0e300);

        -- A value that is not finite has no VHDL real representation
        mock(python_logger, failure);
        vhdl_real := eval("float('inf')");
        check_only_log(
          python_logger,
          "eval(""float('inf')"") failed:" & LF &
          "ValueError: inf cannot be represented as VHDL real",
          failure
        );
        unmock(python_logger);

      elsif run("Test eval of real with underflow from C to VHDL") then
        check_equal(eval("-1.0e300"), -1.0e300);

        mock(python_logger, failure);
        vhdl_real := eval("-float('inf')");
        check_log(
          python_logger,
          "eval(""-float('inf')"") failed:" & LF &
          "ValueError: -inf cannot be represented as VHDL real",
          failure
        );
        vhdl_real := eval("float('nan')");
        check_only_log(
          python_logger,
          "eval(""float('nan')"") failed:" & LF &
          "ValueError: nan cannot be represented as VHDL real",
          failure
        );
        unmock(python_logger);

      elsif run("Test converting integer_vector to Python list string") then
        check_equal(to_py_list_str(empty_integer_vector), "[]");
        check_equal(to_py_list_str(integer_vector'(0 => 1)), "[1]");
        check_equal(to_py_list_str(integer_vector'(-1, 0, 1)), "[-1,0,1]");

      elsif run("Test eval of integer_vector expression") then
        check(eval(to_py_list_str(empty_integer_vector)) = empty_integer_vector);
        check(eval(to_py_list_str(integer_vector'(0 => 17))) = integer_vector'(0 => 17));
        check(eval(to_py_list_str(integer_vector'(integer'low, -1, 0, 1, integer'high))) =
          integer_vector'(integer'low, -1, 0, 1, integer'high)
        );

      elsif run("Test converting integer_vector_ptr to Python list string") then
        vhdl_integer_vector_ptr := new_integer_vector_ptr;
        check_equal(to_py_list_str(vhdl_integer_vector_ptr), "[]");

        vhdl_integer_vector_ptr := new_integer_vector_ptr(1);
        set(vhdl_integer_vector_ptr, 0, 1);
        check_equal(to_py_list_str(vhdl_integer_vector_ptr), "[1]");

        vhdl_integer_vector_ptr := new_integer_vector_ptr(3);
        for idx in 0 to 2 loop
          set(vhdl_integer_vector_ptr, idx, idx - 1);
        end loop;
        check_equal(to_py_list_str(vhdl_integer_vector_ptr), "[-1,0,1]");

      elsif run("Test eval of integer_vector_ptr expression") then
        check_equal(length(eval(to_py_list_str(new_integer_vector_ptr))), 0);

        vhdl_integer_vector_ptr := eval(to_py_list_str(integer_vector'(0 => 17)));
        check_equal(get(vhdl_integer_vector_ptr, 0), 17);

        vhdl_integer_vector_ptr := eval(to_py_list_str(integer_vector'(integer'low, -1, 0, 1, integer'high)));
        check_equal(get(vhdl_integer_vector_ptr, 0), integer'low);
        check_equal(get(vhdl_integer_vector_ptr, 1), -1);
        check_equal(get(vhdl_integer_vector_ptr, 2), 0);
        check_equal(get(vhdl_integer_vector_ptr, 3), 1);
        check_equal(get(vhdl_integer_vector_ptr, 4), integer'high);

      elsif run("Test eval of string expression") then
        check_equal(eval("''"), string'(""));
        check_equal(eval("'\\'"), string'("\"));
        check_equal(eval_string("'Hello from VUnit'"), "Hello from VUnit");
        check_equal(eval_string("'Hello\nWorld'"), "Hello" & LF & "World");

      elsif run("Test converting real_vector to Python list string") then
        check_equal(to_py_list_str(empty_real_vector), "[]");
        check_equal(to_py_list_str(real_vector'(0 => 1.05)), "[1.0500000000000000e+00]");
        check_equal(to_py_list_str(real_vector'(-1.05, 0.0, 1.25)),
          "[-1.0500000000000000e+00,0.0000000000000000e+00,1.2500000000000000e+00]");

      elsif run("Test eval of real_vector expression") then
        check(eval(to_py_list_str(empty_real_vector)) = empty_real_vector);
        check(eval(to_py_list_str(real_vector'(0 => 17.0))) = real_vector'(0 => 17.0));
        vhdl_real_vector := eval(to_py_list_str(test_real_vector));
        for idx in vhdl_real_vector'range loop
          check_equal(vhdl_real_vector(idx), vhdl_real_vector(idx));
        end loop;

      ---------------------------------------------------------------------
      -- Test exec
      ---------------------------------------------------------------------
      elsif run("Test basic exec") then
        exec("py_int = 21");
        check_equal(eval("py_int"), 21);

      elsif run("Test exec with multiple code snippets separated by a semicolon") then
        exec("a = 1; b = 2");
        check_equal(eval("a"), 1);
        check_equal(eval("b"), 2);

      elsif run("Test exec with multiple code snippets separated by a newline") then
        exec(
          "a = 1" & LF &
          "b = 2"
        );
        check_equal(eval("a"), 1);
        check_equal(eval("b"), 2);

      elsif run("Test exec with code construct with indentation") then
        exec(
          "a = [None] * 2" & LF &
          "for idx in range(len(a)):" & LF &
          "    a[idx] = idx"
        );

        check_equal(eval("a[0]"), 0);
        check_equal(eval("a[1]"), 1);

      elsif run("Test a simpler multiline syntax") then
        exec(
          "a = [None] * 2" +
          "for idx in range(len(a)):" +
          "    a[idx] = idx"
        );

        check_equal(eval("a[0]"), 0);
        check_equal(eval("a[1]"), 1);

      elsif run("Test exec of locally defined function") then
        exec(
          "def local_test():" & LF &
          "    return 1"
        );

        check_equal(eval("local_test()"), 1);

      elsif run("Test call functions") then
        check_equal(call("len", arg("Hello")), 5);
        check_equal(call("len", arg(integer_vector'(1, 2, 3))), 3);
        check_equal(call("max", arg(1), arg(2)), 2);
        check_equal(call("max", arg(2.1), arg(1.1)), 2.1);
        check_equal(call("int", arg(true)), 1);

      elsif run("Test call procedure") then
        exec("l = [1]");
        call("l.append", arg(2));
        check_equal(eval("l[1]"), 2);

      elsif run("Test kwarg") then
        arg_value2 := kwarg("kw", 17);
        check_equal(arg_value2.name, "kw");
        check_equal(arg_value2.value, "17");

        arg_value22 := kwarg("kw", 17.5);
        check_equal(arg_value22.name, "kw");
        check_equal(arg_value22.value, "1.7500000000000000e+01");

        arg_value4 := kwarg("kw", "ok");
        check_equal(arg_value4.name, "kw");
        check_equal(arg_value4.value, """ok""");

        arg_value4 := kwarg("kw", true);
        check_equal(arg_value4.name, "kw");
        check_equal(arg_value4.value, "True");

        arg_value22 := kwarg("kw", integer_vector'(1, 2, 3, 4, 5, 6, 7, 8, 9, 10));
        check_equal(arg_value22.name, "kw");
        check_equal(arg_value22.value, "[1,2,3,4,5,6,7,8,9,10]");


      elsif run("Test exec of function defined in run script") then
        import_run_script;
        check_equal(eval("run.remote_test()"), 2);

        import_run_script("my_run_script");
        check_equal(eval("my_run_script.remote_test()"), 2);

        exec("from my_run_script import remote_test");
        check_equal(eval("remote_test()"), 2);

      ---------------------------------------------------------------------
      -- Test error handling
      ---------------------------------------------------------------------
      elsif run("Test exceptions in exec") then
        define_error_helper;
        -- A multiline string argument cannot be passed verbatim to Python, so
        -- the source of the failing exec is kept in a Python variable
        exec(
          "failing_source = 'doing_something_right = 17\n" &
          "doing_something_wrong = doing_something_right_misspelled'"
        );

        mock(python_logger, failure);
        exec(
          "doing_something_right = 17" & LF &
          "doing_something_wrong = doing_something_right_misspelled"
        );
        check_only_log(
          python_logger,
          "exec failed:" & LF & eval_string("expected_error(failing_source, '<exec #3>')"),
          failure
        );
        unmock(python_logger);

      elsif run("Test exceptions in eval") then
        define_error_helper;

        mock(python_logger, failure);
        vhdl_int := eval("1 / 0");
        check_only_log(
          python_logger,
          "eval(""1 / 0"") failed:" & LF &
          call_string(
            "expected_error", arg(string'("1 / 0")), arg(string'("<eval #1>")), arg(true)
          ),
          failure
        );
        unmock(python_logger);

      elsif run("Test eval with type error") then
        mock(python_logger, failure);
        vhdl_int := eval("10 / 2");
        check_only_log(
          python_logger,
          "eval(""10 / 2"") failed:" & LF &
          "TypeError: Cannot convert Python float (5.0) to VHDL integer; expected int",
          failure
        );
        unmock(python_logger);

      elsif run("Test raising exception") then
        define_error_helper;

        mock(python_logger, failure);
        exec("raise RuntimeError('An exception')");
        check_only_log(
          python_logger,
          "exec failed:" & LF &
          call_string(
            "expected_error",
            arg(string'("raise RuntimeError('An exception')")),
            arg(string'("<exec #2>"))
          ),
          failure
        );
        unmock(python_logger);

      ---------------------------------------------------------------------
      -- Misc tests
      ---------------------------------------------------------------------
      elsif run("Test globals and locals") then
        exec("assert(globals() == locals())");

      elsif run("Test print flushing") then
        exec("print('Flushed by the print call', flush=True)");
        exec("print('Flushed by the Python interface')");

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end;
