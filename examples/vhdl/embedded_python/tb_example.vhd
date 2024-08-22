-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.python_context;
use vunit_lib.random_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std_unsigned.all;

entity tb_example is
  generic(
    runner_cfg : string;
    debug_mode : boolean := true
  );
end entity;

architecture tb of tb_example is
  constant clk_period : time := 10 ns;
  signal clk : std_logic := '0';
  signal in_tvalid, in_tlast : std_logic := '0';
  signal in_tdata : std_logic_vector(7 downto 0);
  signal out_tvalid, out_tlast : std_logic := '0';
  signal out_tdata : std_logic_vector(7 downto 0);
  signal crc_error : std_logic;
begin
  test_runner : process
    constant pi : real := 3.141592653589793;
    constant test_real_vector : real_vector := (-3.4028234664e38, -1.9, 0.0, 1.1, -3.4028234664e38);
    constant crc : std_logic_vector(7 downto 0) := x"17";
    constant expected : std_logic_vector(7 downto 0) := x"21";

    variable gcd, vhdl_integer : integer;
    variable test_input, packet : integer_vector_ptr_t;
    variable y : real;
    variable coordinate : real_vector(1 to 3);
    variable input_stimuli : integer_array_t;
    variable seed : integer;
    variable test_lengths : integer_vector_ptr_t;
    variable vhdl_real : real;

    procedure set_tcl_installation is
    begin
      exec("from os import environ");
      exec("from sys import prefix");
      exec("from pathlib import Path");
      exec("old_environ = environ");
      exec(
        "if (Path(prefix) / 'lib' / 'tcl8.6').exists():" +
        "    environ['TCL_LIBRARY'] = str(Path(prefix) / 'lib' / 'tcl8.6')" +
        "else:" +
        "    environ['TCL_LIBRARY'] = str(Path(prefix) / 'tcl' / 'tcl8.6')"
      );
      exec(
        "if (Path(prefix) / 'lib' / 'tk8.6').exists():" +
        "    environ['TK_LIBRARY'] = str(Path(prefix) / 'lib' / 'tk8.6')" +
        "else:" +
        "    environ['TK_LIBRARY'] = str(Path(prefix) / 'tcl' / 'tk8.6')"
      );
    end;

    procedure unset_tcl_installation is
    begin
      exec("environ = old_environ");
    end;

    procedure query_if(expr : boolean; check_result : check_result_t) is
      variable logger : logger_t;
      variable log_level : log_level_t;
      variable line_num : natural;
      variable continue : boolean;
      alias log_check_result is log[check_result_t]; -- TODO: Fix that location preprocessing is too friendly with this
    begin
      if not is_pass(check_result) then
        if expr then
          log_level := get_log_level(check_result);
          logger := get_logger(get_checker(check_result));
          line_num := get_line_num(check_result);

          -- Make the query
          -- @formatter:off
          if line_num = 0 then
            continue := eval("psg.popup_yes_no('" & get_msg(check_result) & "\nDo you want to Continue?', title = '" &
              title(to_string(get_log_level(check_result))) & "')") = string'("Yes");
          else
            continue := eval("psg.popup_yes_no('" & get_msg(check_result) & "\nDo you want to Continue?', title = '" &
              title(to_string(get_log_level(check_result))) & " at " & get_file_name(check_result) & " : " &
              to_string(line_num) & "')") = string'("Yes");
          end if;
          -- @formatter:on

          if continue then
            -- If needed, increase stop count to prevent simulation stop
            if not has_stop_count(logger, log_level) then
              set_stop_count(logger, log_level, 2);
            elsif get_log_count(logger, log_level) = get_stop_count(logger, log_level) - 1 then
              set_stop_count(logger, log_level, get_log_count(logger, log_level) + 2);
            end if;
          end if;
        end if;

        log_check_result(check_result);
      end if;
    end;

    -- TODO: Time to make this part of the VUnit release even though it won't be supported for VHDL-93
    impure function new_integer_vector_ptr(
      vec : integer_vector;
      mode : storage_mode_t := internal;
      eid : index_t := -1
    ) return integer_vector_ptr_t is
      variable result : integer_vector_ptr_t;
      constant vec_normalized : integer_vector(0 to vec'length - 1) := vec;
    begin
      result := new_integer_vector_ptr(vec'length, mode => mode, eid => eid);

      for idx in vec_normalized'range loop
        set(result, idx, vec_normalized(idx));
      end loop;

      return result;
    end;

  begin
    test_runner_setup(runner, runner_cfg);
    python_setup;

    -- To avoid mixup with the Riviera-PRO TCL installation I had to
    -- set the TCL_LIBRARY and TK_LIBRARY environment variables
    -- to the Python installation. TODO: Find a better way if possible
    set_tcl_installation;

    show(display_handler, debug);

    -- @formatter:off
    while test_suite loop
      -------------------------------------------------------------------------------------
      -- Basic eval and exec examples
      -------------------------------------------------------------------------------------
      if run("Test basic exec and eval") then
        -- python_pkg provides the Python functions exec and eval.
        -- exec executes a string of Python code while eval evaluates
        -- a string containing a Python expression. Only eval returns
        -- a value.
        exec("a = -17");
        check_equal(eval("abs(a)"), 17);

      elsif run("Test multiline code") then
        -- Multiline code can be expressed in several ways. At least

        -- 1. Using multiple eval/exec calls:
        exec("a = 5");
        exec("b = 2 * a");
        check_equal(eval("b"), 10);

        -- 2. Using semicolon:
        exec("from math import factorial; a = factorial(5)");
        check_equal(eval("a"), 120);

        -- 3. Using LF:
        exec(
          "l = ['a', 'b', 'c']" & LF &
          "s = ', '.join(l)"
        );
        check_equal(eval("s"), string'("a, b, c"));

        -- 4. Using + as a shorthand for & LF &:
        exec(
          "def fibonacci(n):" +
          "    if n == 0:" +
          "        return [0]" +
          "    elif n == 1:" +
          "        return [0, 1]" +
          "    elif n > 1:" +
          "        result = fibonacci(n - 1)" +
          "        result.append(sum(result[-2:]))" +
          "        return result" +
          "    else:" +
          "        return []");

        exec("print(f'fibonacci(7) = {fibonacci(7)}')");

      elsif run("Test working with Python types") then
        -- Since exec and eval work with strings, VHDL types
        -- must be converted to a suitable string representation
        -- before being used.
        --
        -- Sometimes to_string is enough
        exec("an_integer = " & to_string(17));
        check_equal(eval("an_integer"), 17);

        -- Sometimes a helper function is needed
        exec("a_list = " & to_py_list_str(integer_vector'(1, 2, 3, 4)));
        check_equal(eval("sum(a_list)"), 10);

        -- For eval it is simply a matter of using a suitable
        -- overloaded variant
        coordinate := eval("[1.5, -3.6, 9.1]"); -- coordinate is real_vector(1 to 3)
        check_equal(coordinate(1), 1.5);
        check_equal(coordinate(2), -3.6);
        check_equal(coordinate(3), 9.1);

        -- Every eval has a more explicit alias that may be needed to help the compiler
        exec("from math import pi");
        vhdl_real := eval_real("pi");
        info("pi = " & to_string(vhdl_real));

        -- Since Python is more dynamically typed than VHDL it is sometimes useful to use
        -- dynamic VUnit types
        exec(
          "from random import randint" +
          "test_input = [randint(0, 255) for i in range(randint(1, 100))]");
        test_input := eval("test_input"); -- test_input is a variable of integer_vector_ptr_t type
        check(length(test_input) >= 1);
        check(length(test_input) <= 100);

      elsif run("Test run script functions") then
        -- As we've seen we can define Python functions with exec (fibonacci) and we can import functions from
        -- Python packages. Writing large functions in exec strings is not optimal since we don't
        -- have the support of a Python-aware editor (syntax highlighting etc). Instead we can put our functions
        -- in a Python module, make sure that the module is on the Python search path, and then use a regular import.
        -- However, sometimes it is convenient to simply import a function defined in the run script without
        -- doing any extra steps. That approach is shown below.

        -- Without a parameter to the import_run_script procedure, the imported module will be named after the
        -- run script. In this case the run script is run.py and the module is named run.
        import_run_script;

        -- Now we can call functions defined in the run script
        exec("run.hello_world()");

        -- We can also give a name to the imported module
        import_run_script("my_run_script");
        exec("my_run_script.hello_world()");

        -- Regardless of module name, direct access is also possible
        exec("from my_run_script import hello_world");
        exec("hello_world()");

      elsif run("Test function call helpers") then
        exec("from math import gcd"); -- gcd = greatest common divisor

        -- Function calls are fundamental to using the eval and exec subprograms. To simplify
        -- calls with many arguments, there are a number of helper subprograms. Rather than:
        gcd := eval("gcd(" & to_string(35) & ", " & to_string(77) & ", " & to_string(119) & ")");
        check_equal(gcd, 7);

        -- we can use the call function:
        gcd := call("gcd", to_string(35), to_string(77), to_string(119));
        check_equal(gcd, 7);

        -- Calls within an exec string can also be simplified
        exec("gcd = " & to_call_str("gcd", to_string(35), to_string(77), to_string(119)));
        check_equal(eval("gcd"), 7);

        -- Calls to functions without a return value can be simplified with the call procedure
        call("print", to_string(35), to_string(77), to_string(119));

      -------------------------------------------------------------------------------------
      -- Examples related to error management
      --
      -- Errors can obviously occur in the executed Python code. They will all cause the
      -- test to fail with information about what was the cause
      -------------------------------------------------------------------------------------
      elsif run("Test syntax error") then
        exec(
          "def hello_word():" +
          "    print('Hello World)"); -- Missing a ' after Hello World
        exec("hello_world()");

      elsif run("Test type error") then
        vhdl_integer := eval("1 / 2"); -- Result is a float (0.5) and should be assigned to a real variable

      elsif run("Test Python exception") then
        vhdl_integer := eval("1 / 0"); -- Division by zero exception

      -------------------------------------------------------------------------------------
      -- Examples related to the simulation environment
      --
      -- VHDL comes with some functionality to manage the simulation environment such
      -- as working with files, directories, time, and dates. While this feature set was
      -- extended in VHDL-2019, it is still limited compared to what Python offers and the
      -- VHDL-2019 extensions are yet to be widely supported by simulators. Below are some
      -- examples of what we can do with Python.
      -------------------------------------------------------------------------------------
      elsif run("Test logging simulation platform") then
        -- Logging the simulation platform can be done directly from the run script but
        -- here we get the information included in the same log used by the VHDL code
        exec("from datetime import datetime");
        exec("import platform");
        exec("from vunit import VUnit");

        info(
          colorize("System name: ", cyan) & eval("platform.node()") +
          colorize("Operating system: ", cyan) & eval("platform.platform()") +
          colorize("Processor: ", cyan) & eval("platform.processor()") +
          colorize("Simulator: ", cyan) & eval("VUnit.from_argv().get_simulator_name()") +
          colorize("Simulation started: ", cyan) & eval("datetime.now().strftime('%Y-%m-%d %H:%M:%S')")
        );

      elsif run("Test globbing for files") then
        -- glob finds all files matching a pattern, in this case all CSV in the directory tree rooted
        -- in the testbench directory
        exec("from glob import glob");
        exec("stimuli_files = glob('" & join(tb_path(runner_cfg), "**", "*.csv") & "', recursive=True)");

        for idx in 0 to eval("len(stimuli_files)") - 1 loop
          -- Be aware that you may receive backslashes that should be replaced with forward slashes to be
          -- VHDL compatible
          input_stimuli := load_csv(replace(eval("stimuli_files[" & to_string(idx) & "]"), "\", "/"));

          -- Test with stimuli file...
        end loop;

      -------------------------------------------------------------------------------------
      -- Examples of user interactions
      --
      -- The end goal should always be fully automated testing but during an exploratory
      -- phase and while debugging it can be useful to allow for some user control of
      -- the simulation
      -------------------------------------------------------------------------------------
      elsif run("Test GUI browsing for input stimuli file") then
        if debug_mode then
          exec("import PySimpleGUI as psg"); -- Install PySimpleGUI with pip install pysimplegui
          input_stimuli := load_csv(replace(eval("psg.popup_get_file('Select input stimuli file')"), "\", "/"));
        else
          input_stimuli := load_csv(join(tb_path(runner_cfg), "data", "default", "input_stimuli.csv"));
        end if;

      elsif run("Test querying for randomization seed") then
        if debug_mode then
          exec("import PySimpleGUI as psg");
          seed := integer'value(eval("psg.popup_get_text('Enter seed', default_text='1234')"));
        else
          seed := 1234;
        end if;
        info("Seed = " & to_string(seed));

      elsif run("Test controlling progress of simulation") then
        exec("import PySimpleGUI as psg");

        -- We can let the answers to yes/no pop-ups (psg.popup_yes_no) decide how to proceed,
        -- for example if the simulation shall continue on an error. Putting that into an
        -- action procedure to a check function and we can have a query_if wrapper like this:
        query_if(debug_mode, check_equal(crc, expected, result("for CRC")));

        info("Decided to continue");

      -------------------------------------------------------------------------------------
      -- Example math functions
      --
      -- You can find almost anything in the Python ecosystem so here are just a few
      -- examples of situations where that ecosystem can be helpful
      -------------------------------------------------------------------------------------

      -- Have you ever wished VHDL had some a of the features that SystemVerilog has?
      -- The support for a constraint solver is an example of something SystemVerilog has
      -- and VHDL does not. However, there are Python constraint solvers that might be helpful
      -- if a randomization constraint is difficult to solve with a procedural VHDL code.
      -- This is not such a difficult problem but just an example of using a Python constraint solver.
      elsif run("Test constraint solving") then
        exec("from constraint import Problem"); -- Install with pip install python-constraint
        exec("from random import choice");
        exec(
          "problem = Problem()" +
          "problem.addVariables(['x', 'y', 'z'], list(range(16)))" + -- Three variables in the 0 - 15 range

          -- Constrain the variable
          "problem.addConstraint(lambda x, y, z: x != z)" +
          "problem.addConstraint(lambda x, y, z: y <= z)" +
          "problem.addConstraint(lambda x, y, z: x + y == 8)" +

          -- Pick a random solution
          "solutions = problem.getSolutions()" +
          "solution = choice(solutions)"
        );

        -- Check that the constraints were met
        check(eval_integer("solution['x']") /= eval_integer("solution['z']"));
        check(eval_integer("solution['y']") <= eval_integer("solution['z']"));
        check_equal(eval_integer("solution['x']") + eval_integer("solution['y']"), 8);

      elsif run("Test using a Python module as the golden reference") then
        -- In this example we want to test that a receiver correctly accepts
        -- a packet with a trailing CRC. While we can generate a correct CRC to
        -- our test packets in VHDL, it is easier to use a Python package that
        -- already provides most standard CRC calculations. By doing so, we
        -- also have an independent opinion of how the CRC should be calculated.

        -- crccheck (install with pip install crccheck) supports more than 100 standard CRCs.
        -- Using the 8-bit Bluetooth CRC for this example
        exec("from crccheck.crc import Crc8Bluetooth");

        -- Let's say we should support packet payloads between 1 and 128 bytes and want to test
        -- a subset of those.
        test_lengths := new_integer_vector_ptr(integer_vector'(1, 2, 8, 16, 32, 64, 127, 128));
        for idx in 0 to length(test_lengths) - 1 loop
          -- Randomize a payload but add an extra byte to store the CRC
          packet := random_integer_vector_ptr(get(test_lengths, idx) + 1, min_value => 0, max_value => 255);

          -- Calculate and insert the correct CRC
          exec("packet = " & to_py_list_str(packet));
          set(packet, get(test_lengths, idx), eval("Crc8Bluetooth.calc(packet[:-1])"));

          -- This is where we would apply the generated packet to the tested receiver and verify that the CRC
          -- is accepted as correct
        end loop;

      elsif run("Test using Python in an behavioral model") then
        -- When writing VHDL behavioral models we want the model to be as high-level as possible.
        -- Python creates opportunities to make these models even more high-level

        -- In this example we use the crccheck package to create a behavioral model for a receiver.
        -- Such a model would normally be in a separate process or component so the code below is more
        -- an illustration of the general idea. We have a minimalistic incoming AXI stream (in_tdata/tvalid/tlast)
        -- receiving a packet from a transmitter (at the bottom of this file). The model collects the incoming packet
        -- in a dynamic vector (packet). in_tlast becomes active along with the last recevied byte which is also the
        -- CRC. At that point the packet collected before the CRC is pushed into Python where the expected CRC is
        -- calculated. If it differs from the received CRC, crc_error is set
        --
        -- The model also pass the incoming AXI stream to the output (out_tdata/tvalid/tlast)
        exec("from crccheck.crc import Crc8Bluetooth");
        packet := new_integer_vector_ptr;
        out_tvalid <= '0';
        crc_error <= '0';
        loop
          wait until rising_edge(clk);
          exit when out_tlast;
          out_tvalid <= in_tvalid;
          if in_tvalid then
            out_tdata <= in_tdata;
            out_tlast <= in_tlast;
            if in_tlast then
              exec("packet = " & to_py_list_str(packet));
              crc_error <= '1' when eval_integer("Crc8Bluetooth.calc(packet)") /= to_integer(in_tdata) else '0';
            else
              resize(packet, length(packet) + 1, value => to_integer(in_tdata));
            end if;
          end if;
        end loop;
        check_equal(crc_error, '0');
        out_tvalid <= '0';
        out_tlast <= '0';
        crc_error <= '0';


      ---------------------------------------------------------------------
      -- Examples of string manipulation
      --
      -- Python has tons of functionality for working with string. One of the
      -- features most commonly missed in VHDL is the support for format
      -- specifiers. Here are two ways of dealing with that
      ---------------------------------------------------------------------
      elsif run("Test C-style format specifiers") then
        exec("from math import pi");
        info(eval("'pi is about %.2f' % pi"));

      elsif run("Test Python f-strings") then
        exec("from math import pi");
        info(eval("f'pi is about {pi:.2f}'"));

      ---------------------------------------------------------------------
      -- Examples of plotting
      --
      -- Simulators have a limited set of capabilities when it comes to
      -- Visualize simulation output beyond signal waveforms. Python has
      -- almost endless capabilities
      ---------------------------------------------------------------------
      elsif run("Test simple plot") then
        exec("from matplotlib import pyplot as plt"); -- Matplotlib is installed with pip install matplotlib
        exec("fig = plt.figure()");
        exec("plt.plot([1,2,3,4,5], [1,2,3,4,5])");
        exec("plt.show()");

      elsif run("Test advanced plot") then
        import_run_script("my_run_script");

        exec(
          "from my_run_script import Plot" +
          "plot = Plot(x_points=list(range(360)), y_limits=(-1.1, 1.1), title='Matplotlib Demo'," +
          "            x_label='x [degree]', y_label='y = sin(x)')");

        -- A use case for plotting from VHDL is to monitor the progress of slow simulations where we want to update
        -- the plot as more data points become available. This is not a slow simulation but the updating of the plot
        -- is a bit slow. This is not due to the VHDL code but inherent to Matplotlib. For the use case where we
        -- actually have a slow VHDL simulation, the overhead on the Matplotlib is of no significance.
        for x in 0 to 359 loop
          y := sin(pi * real(x) / 180.0);

          call("plot.update", to_string(x), to_string(y));
        end loop;

        exec("plot.close()");

      end if;
    end loop;
    -- @formatter:on

    -- Revert to old environment variables
    unset_tcl_installation;
    python_cleanup;
    test_runner_cleanup(runner);
  end process;

  clk <= not clk after clk_period / 2;

  packet_transmitter : process is
    -- Packet with valid CRC
    constant packet : integer_vector := (48, 43, 157, 58, 110, 67, 192, 76, 119, 97, 235, 143, 131, 216, 60, 121, 111);
  begin
    -- Transmit the packet once
    in_tvalid <= '0';
    for idx in packet'range loop
      wait until rising_edge(clk);
      in_tdata <= to_slv(packet(idx), in_tdata);
      in_tlast <= '1' when idx = packet'right else '0';
      in_tvalid <= '1';
    end loop;
    wait until rising_edge(clk);
    in_tvalid <= '0';
    in_tlast <= '0';
    wait;
  end process;
end;
