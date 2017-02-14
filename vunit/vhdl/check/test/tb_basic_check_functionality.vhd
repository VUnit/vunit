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
    constant punctuation_marks_not_preceeded_by_space_c : string := ".,:;?!";

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
        base_check_true(default_checker);
        verify_num_of_log_calls(get_count);
        base_check_false(default_checker, "Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        base_check_false(default_checker, "Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        base_check_false(default_checker, "Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        counting_assert(get_logger_init_call_count = cnt, "Should not initialize loggers for basic functionality");
        stat_after := get_checker_stat;
        counting_assert(stat_after = stat_before + (4, 3, 1), "Expected 4 checks, 3 fail, and 1 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify default checker initialization") then
        default_checker_init_from_scratch(default_level => info);
        base_check_false(default_checker, "Check failed.");
        verify_log_call(inc_count, "Check failed.", info);
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

      elsif run("Verify default checker pass messaging and control") then
        default_checker_init_from_scratch;
        base_check_true(default_checker);
        verify_num_of_log_calls(get_count);
        enable_pass_msg(display_handler);
        base_check_true(default_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", true, false);
        disable_pass_msg(display_handler);
        enable_pass_msg(file_handler);
        base_check_true(default_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", false, true);
        disable_pass_msg(file_handler);
        base_check_true(default_checker);
        verify_num_of_log_calls(get_count);
        enable_pass_msg;
        base_check_true(default_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", true, true);
        disable_pass_msg;
        base_check_true(default_checker);
        verify_num_of_log_calls(get_count);

      elsif run("Verify custom checker basic functionality") then
        custom_checker_init_from_scratch(my_checker);
        verify_logger_init_call(set_count(3, get_count(3) + 2), "", "error.csv", level, off, failure, ',', false);
        get_checker_stat(my_checker, stat_before);
        base_check_true(my_checker);
        verify_num_of_log_calls(get_count);
        base_check_false(my_checker, "Custom error message");
        verify_log_call(inc_count, "Custom error message", error);
        base_check_false(my_checker, "Custom level", info);
        verify_log_call(inc_count, "Custom level", info);
        base_check_false(my_checker, "Line and file name", info, 377, "some_file.vhd");
        verify_log_call(inc_count, "Line and file name", info,
                        expected_line_num => 377, expected_file_name => "some_file.vhd");
        get_checker_stat(my_checker, stat_after);
        counting_assert(stat_after = stat_before + (4, 3, 1), "Expected 4 checks, 3 fail, and 1 pass but got " & to_string(stat_after - stat_before));

      elsif run("Verify custom checker initialization") then
        default_checker_init_from_scratch; -- Reset default checker initialization
        verify_logger_init_call(inc_count(3), "", "error.csv", level, off, failure, ',', false);
        custom_checker_init_from_scratch(my_checker,default_level => info);
        inc_count(3);
        base_check_false(my_checker, "Check failed.");
        verify_log_call(inc_count, "Check failed.", info);
        base_check_false(default_checker, "Check failed.");
        verify_log_call(inc_count, "Check failed.", error);
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

      elsif run("Verify custom checker pass messaging and control") then
        custom_checker_init_from_scratch(my_checker);
        base_check_true(my_checker);
        verify_num_of_log_calls(get_count);
        enable_pass_msg(my_checker, display_handler);
        base_check_true(my_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", true, false);
        disable_pass_msg(my_checker, display_handler);
        enable_pass_msg(my_checker, file_handler);
        base_check_true(my_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", false, true);
        disable_pass_msg(my_checker, file_handler);
        base_check_true(my_checker);
        verify_num_of_log_calls(get_count);
        enable_pass_msg(my_checker);
        disable_pass_msg;
        base_check_true(my_checker, "Checking something", 73, "a_file.vhd");
        verify_log_call(inc_count, "Checking something", debug_low2, "",
                        73, "a_file.vhd", true, true);
        disable_pass_msg(my_checker);
        enable_pass_msg;
        base_check_true(my_checker);
        verify_num_of_log_calls(get_count);
        disable_pass_msg;

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
      elsif run("Test that result returns result tag by default") then
        counting_assert(result = check_result_tag_c);
      elsif run("Test that result returns result tag on empty message") then
        counting_assert(result("") = check_result_tag_c);
      elsif run("Test that result returns result tag + message if the message starts with a punctuation mark") then
        for i in punctuation_marks_not_preceeded_by_space_c'range loop
          counting_assert(result(punctuation_marks_not_preceeded_by_space_c(i) & "Foo") =
                          check_result_tag_c & punctuation_marks_not_preceeded_by_space_c(i) & "Foo");
        end loop;
      elsif run("Test that result returns result tag + space + message if the message doesn't start with a punctuation mark") then
        for c in character'left to character'right loop
          if find(punctuation_marks_not_preceeded_by_space_c, c) = 0 then
            counting_assert(result(c & "Foo") =
                            check_result_tag_c & " " & c & "Foo");
          end if;
        end loop;
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
