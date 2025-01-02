-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

use work.phases_pkg.all;

entity tb_phases_minimal is
  generic(
    runner_cfg : string
  );
end entity;

architecture testbench of tb_phases_minimal is
  constant file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "log.txt"), use_color => true);
  constant log_handlers : log_handler_vec_t := (display_handler, file_handler);

  impure function full_coverage return boolean is
  begin
    -- A dummy function but use it to reveal the inner workings of VUnit phases when calling
    -- test_runner_cleanup
    show(get_logger("runner"), display_handler, trace);
    show(get_logger("runner"), file_handler, trace);

    return true;
  end;
begin
  process
  begin
    for idx in log_handlers'range loop
      hide_all(log_handlers(idx));
      show(log_handlers(idx), (info, warning, error, failure, phase_level));
      hide(get_logger("runner"), log_handlers(idx), info);
    end loop;
    set_log_handlers(root_logger, log_handlers);
    wait;
  end process;

  -- @formatter:off
  -- start_snippet test_runner_minimal
  test_runner : process
  begin
    phase("TEST RUNNER SETUP",
      "The testbench is initialized from the runner_cfg generic. This allows for " &
      "configuration of features such as coloration of log entries. This phase " &
      "call comes before initialization, so it will not be affected by any of the " &
      "settings and the resulting log entry will be without special colors."
    );
    test_runner_setup(runner, runner_cfg);

    phase("TEST CASE",
      "This is where we run all the test code."
    );
    reset <= '1';
    wait for 10 ns;
    reset <= '0';
    wait for 10 ns; -- The test code is just a wait statement in this dummy example
    check_equal(error_flag, '0');
    check_true(full_coverage);

    phase("TEST RUNNER CLEANUP",
      "Housekeeping performed by VUnit before ending the simulation. For example, " &
      "if VUnit was configure not to end the simulation upon detecting the first error, " &
      "it will fail the simulation during this phase if any errors have been detected."
    );
    test_runner_cleanup(runner);
  end process;
  -- end_snippet test_runner_minimal
  -- @formatter:on

  test_runner_watchdog(runner, 500 ns);
end architecture;
