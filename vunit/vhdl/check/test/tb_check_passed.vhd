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
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;
use ieee.numeric_std.all;

entity tb_check_passed is
  generic (
    runner_cfg : string);
end entity tb_check_passed;

architecture test_fixture of tb_check_passed is
begin
  test_runner : process
    variable my_checker : checker_t := new_checker("my_checker");
    variable stat : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that default checker check_passed always passes") then
        get_checker_stat(stat);
        check_passed;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);

      elsif run("Test that custom checker check_passed always passes") then
        get_checker_stat(my_checker, stat);
        check_passed(my_checker);
        verify_passed_checks(my_checker, stat, 1);
        verify_failed_checks(my_checker, stat, 0);

      elsif run("Test pass message") then
        mock(check_logger);
        check_passed;
        check_only_log(check_logger, "Unconditional check passed.", pass);

        check_passed("");
        check_only_log(check_logger, "", pass);

        check_passed("Checking my data.");
        check_only_log(check_logger, "Checking my data.", pass);

        check_passed(result("for my data."));
        check_only_log(check_logger, "Unconditional check passed for my data.", pass);
        unmock(check_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

end test_fixture;
