-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;

entity tb_watchdog is
  generic(
    use_boolean_test_signal : boolean := false;
    runner_cfg : string);
end entity;

architecture tb of tb_watchdog is
  signal test_signal, test_boolean, static : boolean;
  signal test_vector : bit_vector(1 downto 0);
  signal condition : boolean := false;
  signal sub_condition : boolean := true;
begin
  test_boolean <= false, false after 500 ps, true after 1000 ps, true after 1400 ps, false after 1500 ps;
  test_vector <= "00", "00" after 500 ps, "11" after 1000 ps, "11" after 1400 ps, "00" after 1500 ps;

  select_test_signal : if use_boolean_test_signal generate
    test_signal <= test_boolean;
  elsif not use_boolean_test_signal generate
    test_signal <= test_vector'stable;
  end generate;
  condition <= false, sub_condition after 1200 ps;

  main : process
    variable t_start : time;
    constant my_logger : logger_t := get_logger("my_logger");
  begin
    test_runner_setup(runner, runner_cfg);
    t_start := now;
    if run("test watchdog no timeout") then
      wait for 1 ns;

    elsif run("Test timeout notification") then
      mock(runner_trace_logger, error);
      wait until timeout_notification(runner);
      check_equal(now, 2 ns);
      wait for 1 ps;
      check_only_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error, 2 ns);
      unmock(runner_trace_logger);

    elsif run("test watchdog timeout") then
      mock(runner_trace_logger, error);
      wait until timeout_notification(runner);
      wait for 1 ps;
      check_only_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error, 2 ns);
      unmock(runner_trace_logger);

    elsif run("test setting timeout") then
      mock(runner_trace_logger, error);
      set_timeout(runner, 10 ns);
      wait until timeout_notification(runner);
      wait for 1 ps;
      check_only_log(runner_trace_logger, "Test runner timeout after " & time'image(10 ns) & ".", error, 10 ns);
      unmock(runner_trace_logger);

    elsif run("test setting timeout several times") then
      mock(runner_trace_logger, error);
      set_timeout(runner, 10 ns);
      wait for 9 ns;
      set_timeout(runner, 100 ns);
      wait until timeout_notification(runner);
      wait for 1 ps;
      check_only_log(runner_trace_logger, "Test runner timeout after " & time'image(100 ns) & ".", error, 109 ns);
      unmock(runner_trace_logger);

    elsif run("Test that wait_on returns on an event with a true condition") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_on(test_signal, condition, 3 ns);
      check_equal(now - t_start, 1500 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_on returns on a timeout regardless of condition") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_on(test_signal, condition, 600 ps);
      check_equal(now - t_start, 600 ps);
      wait_on(test_signal, condition, 700 ps);
      check_equal(now - t_start, 1300 ps);
      check_no_log;
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_on will be notified on a watchdog timeout") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_on(test_signal, condition, 3 ns);
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Test runner timeout while blocking on wait_on." & LF &
                    "Condition is false." & LF &
                    time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test wait_on notification message when condition is true but there are no events") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      wait_on(static, condition, 3 ns);
      check_equal(now - t_start, 3 ns);
      check_log(default_logger, "Test runner timeout while blocking on wait_on." & LF &
                "Condition is true." & LF &
                time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    elsif run("Test that wait_on can take a custom logger") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      sub_condition <= false;
      wait_on(test_signal, condition, 3 ns, my_logger);
      check_equal(now - t_start, 3 ns);
      check_log(my_logger, "Test runner timeout while blocking on wait_on." & LF &
                "Condition is false." & LF &
                time'image(1 ns) & " out of " & time'image(3 ns) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_on without condition") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      wait_on(test_signal, 3 ns);
      check_equal(now - t_start, 1000 ps);
      wait for 0 ns;
      wait_on(test_signal, 3 ns);
      check_equal(now - t_start, 1500 ps);
      wait for 0 ns;
      wait_on(test_signal, 1 ns, my_logger);
      check_equal(now - t_start, 2500 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_on." & LF &
                time'image(500 ps) & " out of " & time'image(1 ns) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_for") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      wait_for(1 ns);
      check_equal(now - t_start, 1 ns);
      wait_for(1500 ps, my_logger);
      check_equal(now - t_start, 2500 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_for." & LF &
                time'image(500 ps) & " out of " & time'image(1500 ps) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test wait_until") then
      mock(runner_trace_logger, error);
      mock(my_logger, info);
      sub_condition <= true;
      wait_until(condition, 100 ps);
      check_equal(now - t_start, 100 ps);
      wait_until(condition, 3 ns);
      check_equal(now - t_start, 1200 ps);
      wait_until(condition, 1 ns, my_logger);
      check_equal(now - t_start, 2200 ps);
      check_log(my_logger, "Test runner timeout while blocking on wait_until." & LF &
                time'image(200 ps) & " out of " & time'image(1 ns) & " remaining on local timeout.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(my_logger);

    elsif run("Test notification message when no timeout has been specified") then
      mock(runner_trace_logger, error);
      mock(default_logger, info);
      sub_condition <= false;
      wait_until(condition);
      check_equal(now - t_start, max_timeout);
      check_log(default_logger, "Test runner timeout while blocking on wait_until.", info);
      check_log(runner_trace_logger, "Test runner timeout after " & time'image(2 ns) & ".", error);
      unmock(runner_trace_logger);
      unmock(default_logger);

    end if;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 2 ns, do_runner_cleanup => false);

end architecture;
