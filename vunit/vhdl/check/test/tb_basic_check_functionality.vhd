-- This test suite verifies basic check functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_base_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_base_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_count.all;
use work.test_support.all;
use std.textio.all;

entity tb_basic_check_functionality is
  generic (
    runner_cfg : string := "";
    output_path : string);
end entity tb_basic_check_functionality;

architecture test_fixture of tb_basic_check_functionality is
begin
  test_runner : process
    procedure banner (
      constant s : in string) is
      variable dashes : string(1 to 256) := (others => '-');
    begin
      report LF & dashes(s'range) & LF & s & LF & dashes(s'range);
    end banner;

    variable pass : boolean;
    variable my_checker : checker_t;
    variable stat, stat1, stat2 : checker_stat_t;
    variable stat_before, stat_after : checker_stat_t;
    variable cfg : checker_cfg_t;
    variable cfg_export : checker_cfg_export_t;
    variable cnt : natural;
  begin
    test_runner_setup(runner, runner_cfg);
    cnt := get_logger_init_call_count;

    while test_suite loop
      if run("Verify default checker basic functionality") then
        stat_before := get_checker_stat;
        check(true);
        verify_num_of_log_calls(get_count);
        check(false);
        verify_log_call(inc_count, "Check failed!", error);
        check(false, "Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        check(false, "Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        check(false, "Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        check(pass, true);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check(true);
        counting_assert(pass, "Should return pass = true on passing check");
        check(pass, false);
        inc_count;
        counting_assert(not pass, "Should return pass = false on failing check");
        pass := check(false);
        inc_count;
        counting_assert(not pass, "Should return pass = false on failing check");
        counting_assert(get_logger_init_call_count = cnt, "Should not initialize loggers for basic functionality");
        stat_after := get_checker_stat;
        counting_assert(stat_after = stat_before + (9, 6, 3), "Expected 9 checks, 6 fail, and 3 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify default check_passed and check_failed") then
        stat_before := get_checker_stat;
        check_passed;
        verify_num_of_log_calls(get_count);
        check_failed;
        verify_log_call(inc_count, "Check failed!", error);
        check_failed("Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        check_failed("Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        check_failed("Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        stat_after := get_checker_stat;
        counting_assert(stat_after = stat_before + (5, 4, 1), "Expected 5 checks, 4 fail, and 1 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify default checker initialization") then
        default_checker_init_from_scratch(default_level => info);
        check(false);
        verify_log_call(inc_count, "Check failed!", info);
        default_checker_init_from_scratch(default_src => "my_testbench");
        verify_logger_init_call(set_count(3, 3), "my_testbench");
        default_checker_init_from_scratch(file_name => "problems.csv");
        verify_logger_init_call(inc_count(3), "", "problems.csv");
        default_checker_init_from_scratch(display_format => verbose_csv);
        verify_logger_init_call(inc_count(3), "", "error.csv", verbose_csv);
        default_checker_init_from_scratch(file_format => verbose_csv);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, verbose_csv);
        default_checker_init_from_scratch(stop_level => error);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, error);
        default_checker_init_from_scratch(separator => '@');
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, '@');
        default_checker_init_from_scratch(append => true);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', true);

      elsif run("Verify custom checker basic functionality") then
        custom_checker_init_from_scratch(my_checker);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', false);
        get_checker_stat(my_checker, stat_before);
        check(my_checker, true);
        verify_num_of_log_calls(get_count);
        check(my_checker, false);
        verify_log_call(inc_count, "Check failed!", error);
        check(my_checker, false, "Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        check(my_checker, false, "Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        check(my_checker, false, "Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        check(my_checker, pass, true);
        counting_assert(pass, "Should return pass = true on passing check");
        check(my_checker, pass, false);
        inc_count;
        counting_assert(not pass, "Should return pass = false on failing check");
        get_checker_stat(my_checker, stat_after);
        counting_assert(stat_after = stat_before + (7, 5, 2), "Expected 7 checks, 5 fail, and 2 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify check_passed and check_failed with custom checker") then
        custom_checker_init_from_scratch(my_checker);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', false);
        get_checker_stat(my_checker, stat_before);
        check_passed(my_checker);
        verify_num_of_log_calls(get_count);
        check_failed(my_checker);
        verify_log_call(inc_count, "Check failed!", error);
        check_failed(my_checker, "Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        check_failed(my_checker, "Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        check_failed(my_checker, "Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        get_checker_stat(my_checker, stat_after);
        counting_assert(stat_after = stat_before + (5, 4, 1), "Expected 5 checks, 4 fail, and 1 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify custom checker initialization") then
        default_checker_init_from_scratch; -- Reset default checker initialization
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', false);
        custom_checker_init_from_scratch(my_checker,default_level => info);
        inc_count(3);
        check(my_checker,false);
        verify_log_call(inc_count, "Check failed!", info);
        check(false);
        verify_log_call(inc_count, "Check failed!", error);  -- Default checker unaffected?
        custom_checker_init_from_scratch(my_checker,default_src => "my_testbench");
        verify_logger_init_call(inc_count(3), "my_testbench");
        custom_checker_init_from_scratch(my_checker,file_name => "problems.csv");
        verify_logger_init_call(inc_count(3), "", "problems.csv");
        custom_checker_init_from_scratch(my_checker,display_format => verbose_csv);
        verify_logger_init_call(inc_count(3), "", "error.csv", verbose_csv);
        custom_checker_init_from_scratch(my_checker,file_format => verbose_csv);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, verbose_csv);
        custom_checker_init_from_scratch(my_checker, stop_level => error);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, error);
        custom_checker_init_from_scratch(my_checker,separator => '@');
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, '@');
        custom_checker_init_from_scratch(my_checker,append => true);
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', true);

      elsif run("Verify checker_stat_t functions and operators") then
        counting_assert(stat1 = (0, 0, 0), "Expected initial stat value = (0, 0, 0)");
        stat1 := (20, 13, 7);
        stat2 := (11, 3, 8);
        counting_assert(stat1 + stat2 = (31, 16, 15), "Expected sum = (31, 16, 15)");
        counting_assert(to_string(stat1) = "Checks: 20" & LF &
                        "Passed:  7" & LF &
                        "Failed: 13",
                        "Format error of checker_stat_t. Got:" & to_string(stat1));
      elsif run("Verify export of configuration") then
        default_checker_init_from_scratch(warning, "__my_src", output_path & "file.csv", verbose_csv, raw, error, ';', true);
        get_checker_cfg(cfg);
        counting_assert(cfg.default_level = warning);
        counting_assert(cfg.logger_cfg.log_default_src.all = "__my_src");
        counting_assert(cfg.logger_cfg.log_file_name.all = output_path & "file.csv");
        counting_assert(cfg.logger_cfg.log_display_format = verbose_csv);
        counting_assert(cfg.logger_cfg.log_file_format = raw);
        counting_assert(cfg.logger_cfg.log_file_is_initialized);
        counting_assert(cfg.logger_cfg.log_stop_level = error);
        counting_assert(cfg.logger_cfg.log_separator = ';');

        get_checker_cfg(cfg_export);
        counting_assert(cfg_export.default_level = warning);
        counting_assert(cfg_export.logger_cfg.log_default_src(1 to 8) = "__my_src");
        counting_assert(cfg_export.logger_cfg.log_default_src_length = 8);
        counting_assert(cfg_export.logger_cfg.log_file_name(1 to 8+output_path'length) = output_path & "file.csv");
        counting_assert(cfg_export.logger_cfg.log_file_name_length = 8+output_path'length);
        counting_assert(cfg_export.logger_cfg.log_display_format = verbose_csv);
        counting_assert(cfg_export.logger_cfg.log_file_format = raw);
        counting_assert(cfg_export.logger_cfg.log_file_is_initialized);
        counting_assert(cfg_export.logger_cfg.log_stop_level = error);
        counting_assert(cfg_export.logger_cfg.log_separator = ';');

        custom_checker_init_from_scratch(my_checker, info, "__my_src2", output_path & "file2.csv", off, verbose_csv, warning, ':', true);
        get_checker_cfg(my_checker, cfg);
        counting_assert(cfg.default_level = info);
        counting_assert(cfg.logger_cfg.log_default_src.all = "__my_src2");
        counting_assert(cfg.logger_cfg.log_file_name.all = output_path & "file2.csv");
        counting_assert(cfg.logger_cfg.log_display_format = off);
        counting_assert(cfg.logger_cfg.log_file_format = verbose_csv);
        counting_assert(cfg.logger_cfg.log_file_is_initialized);
        counting_assert(cfg.logger_cfg.log_stop_level = warning);
        counting_assert(cfg.logger_cfg.log_separator = ':');

        get_checker_cfg(my_checker, cfg_export);
        counting_assert(cfg_export.default_level = info);
        counting_assert(cfg_export.logger_cfg.log_default_src(1 to 9) = "__my_src2");
        counting_assert(cfg_export.logger_cfg.log_default_src_length = 9);
        counting_assert(cfg_export.logger_cfg.log_file_name(1 to 9+output_path'length) = output_path & "file2.csv");
        counting_assert(cfg_export.logger_cfg.log_file_name_length = 9+output_path'length);
        counting_assert(cfg_export.logger_cfg.log_display_format = off);
        counting_assert(cfg_export.logger_cfg.log_file_format = verbose_csv);
        counting_assert(cfg_export.logger_cfg.log_file_is_initialized);
        counting_assert(cfg_export.logger_cfg.log_stop_level = warning);
        counting_assert(cfg_export.logger_cfg.log_separator = ':');

      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
