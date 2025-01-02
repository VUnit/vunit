-- This test suite verifies basic check functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.string_ops.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.ansi_pkg.all;
use work.test_support.all;
use std.textio.all;

use vunit_lib.logger_pkg.all;

entity tb_checker is
  generic (
    runner_cfg : string := "");
end entity;

architecture test_fixture of tb_checker is
begin
  test_runner : process
    variable stat1, stat2 : checker_stat_t;
    variable stat_before, stat_after : checker_stat_t;
    variable my_checker : checker_t := new_checker("my_checker");
    variable my_logger : logger_t := get_logger(my_checker);
    variable passed : boolean;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test default checker") then
        stat_before := get_checker_stat;
        mock(check_logger);

        passing_check(default_checker, "Check true");
        check_only_log(check_logger, "Check true", pass);

        passing_check(default_checker);
        check_only_log(check_logger, "", pass);

        failing_check(default_checker, "Custom error message");
        check_only_log(check_logger, "Custom error message", error);

        failing_check(default_checker, "Custom level", info);
        check_only_log(check_logger, "Custom level", info);

        failing_check(default_checker, "Line and file name", info, line_num => 377, file_name => "some_file.vhd");
        check_only_log(check_logger, "Line and file name", info,
                       line_num => 377, file_name => "some_file.vhd");
        unmock(check_logger);

        stat_after := get_checker_stat;
        assert_true(stat_after = stat_before + (5, 3, 2), "Expected 5 checks, 3 fail, and 2 pass but got " & to_string(stat_after - stat_before));
        reset_checker_stat;

      elsif run("Test custom checker") then
        my_checker := new_checker("my_checker");
        my_logger := get_logger("my_checker");
        assert_true(get_full_name(get_logger(my_checker)) = get_full_name(my_logger));
        stat_before := get_checker_stat(my_checker);

        mock(my_logger);
        passing_check(my_checker, "Check true");
        check_only_log(my_logger, "Check true", pass);

        failing_check(my_checker, "Custom error message");
        check_only_log(my_logger, "Custom error message", error);

        failing_check(my_checker, "Custom level", info);
        check_only_log(my_logger, "Custom level", info);

        failing_check(my_checker, "Line and file name", info, line_num => 377, file_name => "some_file.vhd");
        check_only_log(my_logger, "Line and file name", info,
                       line_num => 377, file_name => "some_file.vhd");
        unmock(my_logger);

        stat_after := get_checker_stat(my_checker);
        assert_true(stat_after = stat_before + (4, 3, 1), "Expected 4 checks, 3 fail, and 1 pass but got " & to_string(stat_after - stat_before));
        reset_checker_stat(my_checker);

      elsif run("Verify checker_stat_t functions and operators") then
        assert_true(stat1 = (0, 0, 0), "Expected initial stat value = (0, 0, 0)");
        stat1 := (20, 13, 7);
        stat2 := (11, 3, 8);
        assert_true(stat1 + stat2 = (31, 16, 15), "Expected sum = (31, 16, 15)");
        passed := to_string(stat1) = "checker_stat'(n_checks => 20, n_failed => 13, n_passed => 7)";
        assert_true(passed, "Format error of checker_stat_t. Got:" & to_string(stat1));

      elsif run("Test checker to/from integer conversion") then
        assert_true(to_checker(to_integer(my_checker)) = my_checker);
        assert_true(to_checker(to_integer(null_checker)) = null_checker);

      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end;
