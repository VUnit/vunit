-- This test suite verifies the check checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;
use work.test_count.all;
use ieee.numeric_std.all;

entity tb_check_failed is
  generic (
    runner_cfg : string);
end entity tb_check_failed;

architecture test_fixture of tb_check_failed is
begin
  test_runner : process
    variable check_failed_checker : checker_t;
    variable stat : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that default checker check_failed always fails") then
        get_checker_stat(stat);
        check_failed;
        verify_log_call(inc_count, "Unconditional check failed.");
        check_failed("");
        verify_log_call(inc_count, "");
        check_failed("Checking my data.");
        verify_log_call(inc_count, "Checking my data.");
        check_failed(result("for my data."));
        verify_log_call(inc_count, "Unconditional check failed for my data.");
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 4);
        reset_checker_stat;
      elsif run("Test that custom checker check_failed always fails") then
        get_checker_stat(check_failed_checker, stat);
        check_failed(check_failed_checker);
        verify_log_call(inc_count, "Unconditional check failed.");
        verify_passed_checks(check_failed_checker, stat, 0);
        verify_failed_checks(check_failed_checker, stat, 1);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

end test_fixture;

-- vunit_pragma run_all_in_same_sim
