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

entity tb_check_passed is
  generic (
    runner_cfg : string);
end entity tb_check_passed;

architecture test_fixture of tb_check_passed is
begin
  test_runner : process
    constant pass_level : log_level_t := debug_low2;
    variable check_passed_checker : checker_t;
    variable stat : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that default checker check_passed always passes") then
        get_checker_stat(stat);
        check_passed;
        verify_num_of_log_calls(get_count);
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
      elsif run("Test that custom checker check_passed always passes") then
        get_checker_stat(check_passed_checker, stat);
        check_passed(check_passed_checker);
        verify_num_of_log_calls(get_count);
        verify_passed_checks(check_passed_checker, stat, 1);
        verify_failed_checks(check_passed_checker, stat, 0);
      elsif run("Test pass message") then
        enable_pass_msg;
        check_passed;
        verify_log_call(inc_count, "Unconditional check passed.", pass_level);
        check_passed("");
        verify_log_call(inc_count, "", pass_level);
        check_passed("Checking my data.");
        verify_log_call(inc_count, "Checking my data.", pass_level);
        check_passed(result("for my data."));
        verify_log_call(inc_count, "Unconditional check passed for my data.", pass_level);
        disable_pass_msg;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

end test_fixture;

-- vunit_pragma run_all_in_same_sim
