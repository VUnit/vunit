-- This test suite verifies the check checker.
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
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use work.test_support.all;
use ieee.numeric_std.all;

entity tb_check_failed is
  generic (
    runner_cfg : string);
end entity tb_check_failed;

architecture test_fixture of tb_check_failed is
begin
  test_runner : process
    variable my_checker : checker_t := new_checker("my_checker");
    variable my_logger : logger_t := get_logger(my_checker);
    variable stat : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that default checker check_failed always fails") then
        get_checker_stat(stat);

        mock(check_logger);
        check_failed;
        check_only_log(check_logger, "Unconditional check failed.", error);

        check_failed("");
        check_only_log(check_logger, "", error);

        check_failed("Checking my data.");
        check_only_log(check_logger, "Checking my data.", error);

        check_failed(result("for my data."));
        check_only_log(check_logger, "Unconditional check failed for my data.", error);
        unmock(check_logger);

        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 4);
        reset_checker_stat;

      elsif run("Test that custom checker check_failed always fails") then
        get_checker_stat(my_checker, stat);

        mock(my_logger);
        check_failed(my_checker);
        check_only_log(my_logger, "Unconditional check failed.", error);
        unmock(my_logger);

        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 1);
        reset_checker_stat(my_checker);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

end test_fixture;
