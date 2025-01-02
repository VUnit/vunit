-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.event_pkg.all;

entity tb_watchdog is
  generic (
    runner_cfg : string);
end entity;

architecture tb of tb_watchdog is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test watchdog no timeout") then
      wait for 1 ns;

    elsif run("Test watchdog timeout") then
      mock(runner_trace_logger, error);
      wait until is_active_msg(runner_timeout);
      check_equal(now, 2 ns);
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

    end if;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 2 ns, do_runner_cleanup => false);

end architecture;
