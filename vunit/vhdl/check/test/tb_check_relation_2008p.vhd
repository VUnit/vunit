-- This test suite verifies the check_relation checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;

entity tb_check_relation_2008 is
  generic (
    runner_cfg : string);
end entity;

architecture test_fixture of tb_check_relation_2008 is
  signal sl_0 : std_logic := '0';
  signal sl_1 : std_logic := '1';
  signal bit_0 : bit := '0';
  signal bit_1 : bit := '1';
begin

  test_runner : process
    constant default_level : log_level_t := error;
    variable stat : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that VHDL 2008 matching relational operators are supported") then
        get_checker_stat(stat);
        mock(check_logger);
        check_relation(sl_1 ?= sl_0);
        check_only_log(check_logger, "Relation check failed - Expected sl_1 ?= sl_0. Left is 1. Right is 0.", default_level);

        check_relation(bit_1 ?= bit_0);
        check_only_log(check_logger, "Relation check failed - Expected bit_1 ?= bit_0. Left is 1. Right is 0.", default_level);

        check_relation(sl_1 ?/= sl_1);
        check_only_log(check_logger, "Relation check failed - Expected sl_1 ?/= sl_1. Left is 1. Right is 1.", default_level);

        check_relation(sl_1 ?< sl_0);
        check_only_log(check_logger, "Relation check failed - Expected sl_1 ?< sl_0. Left is 1. Right is 0.", default_level);

        check_relation(sl_1 ?<= sl_0);
        check_only_log(check_logger, "Relation check failed - Expected sl_1 ?<= sl_0. Left is 1. Right is 0.", default_level);

        check_relation(sl_0 ?> sl_1);
        check_only_log(check_logger, "Relation check failed - Expected sl_0 ?> sl_1. Left is 0. Right is 1.", default_level);

        check_relation(sl_0 ?>= sl_1);
        check_only_log(check_logger, "Relation check failed - Expected sl_0 ?>= sl_1. Left is 0. Right is 1.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 7);
        reset_checker_stat;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 1 us);

end test_fixture;
