-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- This test suite verifies wait_pkg

library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.wait_pkg.all;

entity tb_wait_pkg is
  generic(
    use_boolean_test_signal : boolean := false;
    runner_cfg : string);
end entity;

architecture tb of tb_wait_pkg is
  signal source, source_boolean, static : boolean;
  signal source_non_boolean : bit_vector(1 downto 0);
  signal condition : boolean := false;
  signal sub_condition : boolean := true;
  signal event : boolean;
  function conditional_expression(condition : boolean) return boolean is
  begin
    return condition;
  end;
begin
  source_boolean <= false, false after 500 ps, true after 1000 ps, true after 1400 ps, false after 1500 ps;
  source_non_boolean <= "00", "00" after 500 ps, "11" after 1000 ps, "11" after 1400 ps, "00" after 1500 ps;

  select_boolean_source_signal : if use_boolean_test_signal generate
    source <= source_boolean;
  end generate;

  select_non_boolean_source_signal : if not use_boolean_test_signal generate
    source <= source xor source_non_boolean'event; -- The user can create a boolean source from a non-boolean source
  end generate;

  condition <= false, sub_condition after 1200 ps;

  sense(event, source, condition);

  main : process
    variable t_start : time;
    constant my_logger : logger_t := get_logger("my_logger");
  begin
    test_runner_setup(runner, runner_cfg);
    t_start := now;

    if run("Test that wait_until returns on an event with a true condition") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_until(source, condition, 3 ns);
      check_equal(now - t_start, 1500 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_until returns on a timeout regardless of condition") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_until(source, condition, 600 ps);
      check_equal(now - t_start, 600 ps);
      wait_until(source, condition, 700 ps);
      check_equal(now - t_start, 1300 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_until will be notified on a watchdog timeout") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_until(source, condition, 3 ns);
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Test runner timeout while blocking on wait_until." & LF & "Condition is false." & LF & time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info,
                2 ns, 81, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test wait_until notification message when condition is true but there are no events") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_until(static, condition, 3 ns);
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Test runner timeout while blocking on wait_until." & LF & "Condition is true." & LF & time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info,
                2 ns, 92, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_until can take a custom logger") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      sub_condition <= false;
      wait_until(source, condition, 3 ns, logger => my_logger);
      check_equal(now - t_start, 3 ns);
      check_log(my_logger, "Test runner timeout while blocking on wait_until." & LF & "Condition is false." & LF & time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info,
                2 ns, 104, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_on") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      wait_on(source, 3 ns);
      check_equal(now - t_start, 1000 ps);
      wait for 0 ns;
      wait_on(source, 3 ns);
      check_equal(now - t_start, 1500 ps);
      wait for 0 ns;
      wait_on(source, 1 ns, logger => my_logger);
      check_equal(now - t_start, 2500 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_on." & LF & time'image(500 ps) & " out of " & time'image(1 ns) & " remaining on local timeout.", info,
                2 ns, 121, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_on with multiple sources") then
      while not conditional_expression(condition) loop
        wait_on(event, 3 ns);
      end loop;
      check_equal(now - t_start, 1200 ps);

    elsif run("Test wait_on with custom message") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_until(source, condition, 3 ns, msg => "Waiting on test_signal.");
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Waiting on test_signal.", info, 2 ns, 139, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test wait_until with decorated custom message") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_until(source, condition, 3 ns, msg => timeout_msg("Waiting on test_signal."));
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Test runner timeout while blocking on wait_until." & LF & "Waiting on test_signal." & LF & "Condition is false." & LF & time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info,
                2 ns, 150, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test wait_for") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      wait_for(1 ns);
      check_equal(now - t_start, 1 ns);
      wait_for(1500 ps, my_logger);
      check_equal(now - t_start, 2500 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_for." & LF & time'image(500 ps) & " out of " & time'image(1500 ps) & " remaining on local timeout.", info,
                2 ns, 163, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_until without source") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      sub_condition <= true;
      wait_until(condition, 100 ps);
      check_equal(now - t_start, 100 ps);
      wait_until(condition, 3 ns);
      check_equal(now - t_start, 1200 ps);
      wait_until(condition, 1 ns, logger => my_logger);
      check_equal(now - t_start, 2200 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_until." & LF & time'image(200 ps) & " out of " & time'image(1 ns) & " remaining on local timeout.", info,
                2 ns, 179, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test notification message when no timeout has been specified") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_until(condition);
      check_equal(now - t_start, max_timeout);
      check_log(default_logger, "Test runner timeout while blocking on wait_until.", info,
                2 ns, 191, "tb_wait_pkg.vhd");
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_until returns immediately on a true condition if initial_eval is true") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_until(source, condition, 3 ns);
      check_equal(now - t_start, 1500 ps);
      check_true(source'event);
      wait_until(source, condition, 1 ps);
      check_equal(now - t_start, 1501 ps);
      check_false(source'event);
      for iter in 1 to 5 loop
        wait_until(source, condition, 3 ns, initial_eval => true);
      end loop;
      check_equal(now - t_start, 1501 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_on returns immediately on a true source'event if initial_eval is true") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_on(source, 3 ns);
      check_equal(now - t_start, 1000 ps);
      check_true(source'event);
      for iter in 1 to 5 loop
        wait_on(source, 3 ns, initial_eval => true);
      end loop;
      check_equal(now - t_start, 1000 ps);
      check_true(source'event);
      wait_on(source, 1 ps);
      check_equal(now - t_start, 1001 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    end if;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 2 ns, do_runner_cleanup => false);

end architecture;
