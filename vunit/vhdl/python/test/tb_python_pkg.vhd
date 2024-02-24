-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
-- Keep this as an add-on while developing
-- but eventually I think it should be included
-- by default for supporting simulators
context vunit_lib.python_context;
use vunit_lib.runner_pkg.all;

library ieee;
use ieee.math_real.all;

entity tb_python_pkg is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_python_pkg is
begin
  test_runner : process
    constant empty_integer_vector : integer_vector(0 downto 1) := (others => 0);
    constant empty_real_vector : real_vector(0 downto 1) := (others => 0.0);
    constant test_real_vector : real_vector := (-3.4028234664e38, -1.9, 0.0, 1.1, -3.4028234664e38);
    constant max_int : integer := 2 ** 30 - 1 + 2 ** 30;
    constant min_int : integer := -2 ** 30 - 2 ** 30;

    variable vhdl_int : integer;
    variable vhdl_real : real;
    variable vhdl_real_vector : real_vector(test_real_vector'range);
    variable vhdl_integer_vector_ptr : integer_vector_ptr_t;
    variable vhdl_integer_vector : integer_vector(0 to 3);

  begin
    test_runner_setup(runner, runner_cfg);
    -- While developing, python_setup and cleanup are separate
    -- procedures. Eventually they will probably be part of test_runner_setup
    -- and cleanup
    python_setup;

    show(display_handler, debug);

    -- @formatter:off
    while test_suite loop
    ---------------------------------------------------------------------
    -- Test eval of different types
    ---------------------------------------------------------------------
      if run("Test eval of integer expression") then
        check_equal(eval("17"), 17);
        check_equal(eval("2**31 - 1"), max_int);
        check_equal(eval("-2**31"), min_int);

      elsif run("Test eval of integer with overflow from Python to C") then
        vhdl_int := eval("2**63");

      elsif run("Test eval of integer with underflow from Python to C") then
        vhdl_int := eval("-2**63 - 1");

      elsif run("Test eval of integer with overflow from C to VHDL") then
        vhdl_int := eval("2**31");

      elsif run("Test eval of integer with underflow from C to VHDL") then
        vhdl_int := eval("-2**31 - 1");

      elsif run("Test eval of real expression") then
        check_equal(eval("3.40282346e38"), 3.40282346e38);
        check_equal(eval("1.1754943508e-38"), 1.1754943508e-38);
        check_equal(eval("-3.4028e38"), -3.4028e38);
        check_equal(eval("-1.1754943508e-38"), -1.1754943508e-38);

      elsif run("Test eval of real with overflow from C to VHDL") then
        vhdl_real := eval("3.4028234665e38");

      elsif run("Test eval of real with underflow from C to VHDL") then
        vhdl_real := eval("-3.4028234665e38");

      elsif run("Test converting integer_vector to Python list string") then
        check_equal(to_py_list_str(empty_integer_vector), "[]");
        check_equal(to_py_list_str(integer_vector'(0 => 1)), "[1]");
        check_equal(to_py_list_str(integer_vector'(-1, 0, 1)), "[-1,0,1]");

      elsif run("Test eval of integer_vector expression") then
        check(eval(to_py_list_str(empty_integer_vector)) = empty_integer_vector);
        check(eval(to_py_list_str(integer_vector'(0 => 17))) = integer_vector'(0 => 17));
        check(eval(to_py_list_str(integer_vector'(min_int, -1, 0, 1, max_int))) =
          integer_vector'(min_int, -1, 0, 1, max_int)
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

        vhdl_integer_vector_ptr := eval(to_py_list_str(integer_vector'(min_int, -1, 0, 1, max_int)));
        check_equal(get(vhdl_integer_vector_ptr, 0), min_int);
        check_equal(get(vhdl_integer_vector_ptr, 1), -1);
        check_equal(get(vhdl_integer_vector_ptr, 2), 0);
        check_equal(get(vhdl_integer_vector_ptr, 3), 1);
        check_equal(get(vhdl_integer_vector_ptr, 4), max_int);

      elsif run("Test eval of string expression") then
        check_equal(eval("''"), string'(""));
        check_equal(eval("'\\'"), string'("\"));
        check_equal(eval_string("'Hello from VUnit'"), "Hello from VUnit");

        -- TODO: We could use a helper function converting newlines to VHDL linefeeds
        check_equal(eval_string("'Hello\\nWorld'"), "Hello\nWorld");

      elsif run("Test converting real_vector to Python list string") then
        check_equal(to_py_list_str(empty_real_vector), "[]");
        -- TODO: real'image creates a scientific notation with an arbitrary number of
        -- digits that makes the string representation hard to predict/verify.
        -- check_equal(to_py_list_str(real_vector'(0 => 1.1)), "[1.1]");
        -- check_equal(to_py_list_str(real_vector'(-1.1, 0.0, 1.3)), "[-1.1,0.0,1.3]");

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
        exec(
          "doing_something_right = 17" & LF &
          "doing_something_wrong = doing_something_right_misspelled"
        );

      elsif run("Test exceptions in eval") then
        vhdl_int := eval("1 / 0");

      elsif run("Test eval with type error") then
        vhdl_int := eval("10 / 2");

      elsif run("Test raising exception") then
        -- TODO: It fails as expected but the feedback is a bit strange
        exec("raise RuntimeError('An exception')");

      ---------------------------------------------------------------------
      -- Misc tests
      ---------------------------------------------------------------------
      elsif run("Test globals and locals") then
        exec("assert(globals() == locals())");

      elsif run("Test print flushing") then
        -- TODO: Observing that for some simulators the buffer isn't flushed
        -- until the end of simulation
        exec("from time import sleep");
        exec("print('Before sleep', flush=True)");
        exec("sleep(5)");
        exec("print('After sleep')");

      end if;
    end loop;
    -- @formatter:on

    python_cleanup;
    test_runner_cleanup(runner);
  end process;
end;
