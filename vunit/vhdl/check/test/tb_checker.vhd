-- This test suite verifies basic check functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

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
    runner_cfg : string := "";
    output_path : string);
end entity;

architecture test_fixture of tb_checker is
begin
  test_runner : process
    variable my_checker : checker_t := new_checker("my_checker");
    variable checker1, checker2 : checker_t;
    variable my_logger : logger_t := get_logger(my_checker);
    variable stat, stat1, stat2 : checker_stat_t;
    variable stat_before, stat_after : checker_stat_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test default checker") then
        stat_before := get_checker_stat;
        mock(check_logger);

        passing_check(default_checker, "Check true");
        check_only_log(check_logger, "Check true", pass);

        passing_check(default_checker);
        check_no_log(check_logger);

        failing_check(default_checker, "Custom error message");
        check_only_log(check_logger, "Custom error message", error);

        failing_check(default_checker, "Custom level", info);
        check_only_log(check_logger, "Custom level", info);

        failing_check(default_checker, "Line and file name", info, 377, "some_file.vhd");
        check_only_log(check_logger, "Line and file name", info,
                       line_num => 377, file_name => "some_file.vhd");
        unmock(check_logger);

        stat_after := get_checker_stat;
        assert_true(stat_after = stat_before + (5, 3, 2), "Expected 5 checks, 3 fail, and 2 pass but got " & to_string(stat_after - stat_before));
        reset_checker_stat;

      elsif run("Test custom checker") then
        stat_before := get_stat(my_checker);

        mock(my_logger);
        passing_check(my_checker, "Check true");
        check_only_log(my_logger, "Check true", pass);

        failing_check(my_checker, "Custom error message");
        check_only_log(my_logger, "Custom error message", error);

        failing_check(my_checker, "Custom level", info);
        check_only_log(my_logger, "Custom level", info);

        failing_check(my_checker, "Line and file name", info, 377, "some_file.vhd");
        check_only_log(my_logger, "Line and file name", info,
                       line_num => 377, file_name => "some_file.vhd");
        unmock(my_logger);

        stat_after := get_stat(my_checker);
        assert_true(stat_after = stat_before + (4, 3, 1), "Expected 4 checks, 3 fail, and 1 pass but got " & to_string(stat_after - stat_before));
        reset_checker_stat(my_checker);

      elsif run("Verify checker_stat_t functions and operators") then
        assert_true(stat1 = (0, 0, 0), "Expected initial stat value = (0, 0, 0)");
        stat1 := (20, 13, 7);
        stat2 := (11, 3, 8);
        assert_true(stat1 + stat2 = (31, 16, 15), "Expected sum = (31, 16, 15)");
        assert_true(to_string(stat1) = "checker_stat'(n_checks => 20, n_failed => 13, n_passed => 7)",
                        "Format error of checker_stat_t. Got:" & to_string(stat1));

      elsif run("Test get checker name") then
        checker1 := new_checker("foo");
        assert get_name(checker1) = "foo";

      elsif run("Test num checkers and get checkers") then
        for i in 0 to num_checkers-1 loop
          info(get_name(get_checker(i)));
        end loop;

        checker1 := new_checker("foo");
        assert num_checkers = 3;
        assert get_name(get_checker(num_checkers-1)) = "foo";

        checker1 := new_checker("bar");
        assert num_checkers = 4;
        assert get_name(get_checker(num_checkers-1)) = "bar";

      elsif run("Test that checkers with same name can not be created") then
        checker1 := new_checker("foo");
        mock(default_logger);
        checker2 := new_checker("foo");
        check_only_log(default_logger, "Checker with name ""foo"" already exists.", failure);
        unmock(default_logger);
      elsif run("Test that a green pass level exists") then
        assert get_name(pass) = "pass";
        assert get_color(pass) = (fg => green, bg => no_color, style => bright);
        assert pass = log_level_t'val((log_level_t'pos(debug) + log_level_t'pos(verbose)) / 2);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end;
