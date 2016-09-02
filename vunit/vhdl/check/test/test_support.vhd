-- This package provides various test support for the checker test suites.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
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
use work.test_count.all;
use std.textio.all;

package test_support is
  procedure default_checker_init_from_scratch (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in log_format_t := level;
    constant file_format    : in log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false);

  procedure custom_checker_init_from_scratch (
    variable checker               : inout checker_t;
    constant default_level        : in    log_level_t := error;
    constant default_src          : in    string      := "";
    constant file_name            : in    string      := "error.csv";
    constant display_format : in    log_format_t  := level;
    constant file_format    : in    log_format_t  := off;
    constant stop_level : in log_level_t := failure;
    constant separator            : in    character   := ',';
    constant append               : in    boolean     := false);

  procedure counting_assert (
    constant expr : in boolean;
    constant msg  : in string := "";
    constant level : in severity_level := error);

  procedure verify_log_call (
    constant expected_count  : in natural;
    constant expected_msg : in string := "Check failed!";
    constant expected_level  : in log_level_t := error;
    constant expected_src : in string := "";
    constant expected_line_num : in natural := 0;
    constant expected_file_name : in string := "");

  procedure verify_time_log_call (
    constant expected_count  : in natural;
    constant got_time : in time;
    constant expected_time : in time;
    constant expected_level  : in log_level_t := error;
    constant expected_src : in string := "";
    constant expected_line_num : in natural := 0;
    constant expected_file_name : in string := "");

  procedure verify_logger_init_call (
    constant expected_count  : in natural;
    constant expected_default_src : in string := "";
    constant expected_file_name : in string := "error.csv";
    constant expected_display_format  : in log_format_t := level;
    constant expected_file_format  : in log_format_t := off;
    constant expected_stop_level  : in log_level_t := failure;
    constant expected_separator : in character := ',';
    constant expected_append : in boolean := false);

  procedure verify_passed_checks (
    variable stat : inout checker_stat_t;
    constant expected_n_passed : in integer := -1);

  procedure verify_passed_checks (
    variable checker : inout checker_t;
    variable stat : inout checker_stat_t;
    constant expected_n_passed : in integer := -1);

  procedure verify_failed_checks (
    variable stat : inout checker_stat_t;
    constant expected_n_failed : in integer := -1);

  procedure verify_failed_checks (
    variable checker : inout checker_t;
    variable stat : inout checker_stat_t;
    constant expected_n_failed : in integer := -1);

  procedure verify_num_of_log_calls (
    constant expected_count  : in natural);

  procedure apply_sequence (
    constant seq : in string;
    signal clk        : in  std_logic;
    signal data       : out std_logic;
    constant active_rising_clk_edge : in boolean := true);

  procedure apply_sequence (
    constant seq : in string;
    signal clk        : in  std_logic;
    signal data       : out std_logic_vector;
    constant active_rising_clk_edge : in boolean := true);

  procedure banner (
    constant s : in string);

  procedure print_test_result;

  procedure get_and_print_test_result (
    variable stat : out checker_stat_t);

  function clock_edge (
    signal clk                : in std_logic;
    constant wait_rising_edge : in boolean := true)
    return boolean;

end package test_support;

package body test_support is
  constant asserts : natural := 0;
  constant errors : natural := 1;
  constant unexpected_errors : natural := 2;

  procedure default_checker_init_from_scratch (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in log_format_t := level;
    constant file_format    : in log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append               : in    boolean     := false) is
  begin
    vunit_lib.check_pkg.checker_init(default_level, default_src, file_name, display_format, file_format,
                                     stop_level, separator, append);
  end;

  procedure custom_checker_init_from_scratch (
    variable checker               : inout checker_t;
    constant default_level        : in    log_level_t := error;
    constant default_src          : in    string      := "";
    constant file_name            : in    string      := "error.csv";
    constant display_format : in    log_format_t  := level;
    constant file_format    : in    log_format_t  := off;
    constant stop_level : in log_level_t := failure;
    constant separator            : in    character   := ',';
    constant append               : in    boolean     := false) is
  begin
    vunit_lib.check_base_pkg.base_init(checker, default_level, default_src, file_name, display_format,
                                       file_format, stop_level, separator, append);
  end;

  procedure counting_assert (
    constant expr : in boolean;
    constant msg  : in string := "";
    constant level : in severity_level := error) is
  begin  -- procedure counting_assert
    inc_count(asserts);
    if not expr then
      assert false report msg severity level;
      inc_count(unexpected_errors);
    end if;
  end procedure counting_assert;

  procedure verify_log_call (
    constant expected_count  : in natural;
    constant expected_msg : in string := "Check failed!";
    constant expected_level  : in log_level_t := error;
    constant expected_src : in string := "";
    constant expected_line_num : in natural := 0;
    constant expected_file_name : in string := "") is
    variable call_count : natural;
    variable log_call_args : log_call_args_t;
  begin
    call_count := get_log_call_count;
    counting_assert(call_count = expected_count, "Invalid report call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".");
    get_log_call_args(log_call_args);
    counting_assert(log_call_args.valid, "Log not called");
    counting_assert(log_call_args.msg(expected_msg'range) = expected_msg, "Wrong message. Got " &  log_call_args.msg(expected_msg'range) & " but expected " & expected_msg & ".");
    counting_assert(log_call_args.level = expected_level, "Wrong level.", error);
    counting_assert(log_call_args.src(expected_src'range) = expected_src, "Wrong source. Got " &  log_call_args.src(expected_src'range) & " but expected " & expected_src & ".");
    counting_assert(log_call_args.line_num = expected_line_num, "Wrong line number.", error);
    counting_assert(log_call_args.file_name(expected_file_name'range) = expected_file_name, "Wrong file_name. Got " &  log_call_args.file_name(expected_file_name'range) & " but expected " & expected_file_name & ".");
  end verify_log_call;

    procedure verify_time_log_call (
      constant expected_count  : in natural;
      constant got_time : in time;
      constant expected_time : in time;
      constant expected_level  : in log_level_t := error;
      constant expected_src : in string := "";
      constant expected_line_num : in natural := 0;
      constant expected_file_name : in string := "") is
      variable call_count : natural;
      variable log_call_args : log_call_args_t;
      variable times : lines_t;
    begin
      call_count := get_log_call_count;
      counting_assert(call_count = expected_count, "Invalid report call count. Got " & natural'image(call_count) &
                      " but was expecting " & natural'image(expected_count) & ".");
      get_log_call_args(log_call_args);
      counting_assert(log_call_args.valid, "Log not called");

      times := split(replace(replace(replace(strip(log_call_args.msg, "" & NUL),
                                             "Equality check failed! Got ", ""), ". Expected ", "|"), '.', ""), "|");
      counting_assert(((time'value(times(0).all) = got_time) and (time'value(times(1).all) = expected_time)),
                       "Wrong message. Got " & log_call_args.msg & " but expected " &
                       "Equality check failed! Got " & time'image(got_time) & ". Expected " &
                       time'image(expected_time) & ".");

      counting_assert(log_call_args.level = expected_level, "Wrong level.", error);
      counting_assert(log_call_args.src(expected_src'range) = expected_src, "Wrong source. Got " &
                      log_call_args.src(expected_src'range) & " but expected " & expected_src & ".");
      counting_assert(log_call_args.line_num = expected_line_num, "Wrong line number.", error);
      counting_assert(log_call_args.file_name(expected_file_name'range) = expected_file_name,
                      "Wrong file_name. Got " &  log_call_args.file_name(expected_file_name'range) &
                      " but expected " & expected_file_name & ".");
    end verify_time_log_call;

  procedure verify_logger_init_call (
    constant expected_count  : in natural;
    constant expected_default_src : in string := "";
    constant expected_file_name : in string := "error.csv";
    constant expected_display_format  : in log_format_t := level;
    constant expected_file_format  : in log_format_t := off;
    constant expected_stop_level  : in log_level_t := failure;
    constant expected_separator : in character := ',';
    constant expected_append : in boolean := false) is
    variable call_count : natural;
    variable logger_init_call_args : logger_init_call_args_t;
  begin
    call_count := get_logger_init_call_count;
    counting_assert(call_count = expected_count, "Invalid report call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".");
    get_logger_init_call_args(logger_init_call_args);
    counting_assert(logger_init_call_args.valid, "Init not called");
    counting_assert(logger_init_call_args.default_src(expected_default_src'range) = expected_default_src, "Wrong default source. Got " &  logger_init_call_args.default_src(expected_default_src'range) & " but expected " & expected_default_src & ".");
    counting_assert(logger_init_call_args.file_name(expected_file_name'range) = expected_file_name, "Wrong file name. Got " &  logger_init_call_args.file_name(expected_file_name'range) & " but expected " & expected_file_name & ".");
    counting_assert(logger_init_call_args.display_format = expected_display_format, "Wrong display format.", error);
    counting_assert(logger_init_call_args.file_format = expected_file_format, "Wrong file format.", error);
    counting_assert(logger_init_call_args.stop_level = expected_stop_level, "Wrong stop level.", error);
    counting_assert(logger_init_call_args.separator = expected_separator, "Wrong separator.", error);
    counting_assert(logger_init_call_args.append = expected_append, "Wrong append value.", error);
  end verify_logger_init_call;

  procedure verify_passed_checks (
    variable stat : inout checker_stat_t;
    constant expected_n_passed : in integer := -1) is
    variable new_stat : checker_stat_t;
    variable n_passed : natural;
  begin
    verify_passed_checks(default_checker, stat, expected_n_passed);
  end;

  procedure verify_passed_checks (
    variable checker : inout checker_t;
    variable stat : inout checker_stat_t;
    constant expected_n_passed : in integer := -1) is
    variable new_stat : checker_stat_t;
    variable n_passed : natural;
  begin
    get_checker_stat(checker, new_stat);
    if expected_n_passed = -1 then
      counting_assert(new_stat.n_passed > stat.n_passed, "No passed checks registered.");
    else
      counting_assert(new_stat.n_passed = stat.n_passed + expected_n_passed, "Not expected number of passed checks registered. Got " & integer'image(new_stat.n_passed) & " but expected " & integer'image(stat.n_passed + expected_n_passed) & ".");
    end if;
  end;

  procedure verify_failed_checks (
    variable stat : inout checker_stat_t;
    constant expected_n_failed : in integer := -1) is
    variable new_stat : checker_stat_t;
    variable n_failed : natural;
  begin
    verify_failed_checks(default_checker, stat, expected_n_failed);
  end;

  procedure verify_failed_checks (
    variable checker : inout checker_t;
    variable stat : inout checker_stat_t;
    constant expected_n_failed : in integer := -1) is
    variable new_stat : checker_stat_t;
    variable n_failed : natural;
  begin
    get_checker_stat(checker, new_stat);
    if expected_n_failed = -1 then
      counting_assert(new_stat.n_failed > stat.n_failed, "No failed checks registered.");
    else
      counting_assert(new_stat.n_failed = stat.n_failed + expected_n_failed, "Not expected number of failed checks registered. Got " & integer'image(new_stat.n_failed) & " but expected " & integer'image(stat.n_failed + expected_n_failed) & ".");
    end if;
  end;

  procedure verify_num_of_log_calls (
    constant expected_count  : in natural) is
    variable call_count : natural;
    variable stat : checker_stat_t;
  begin
    call_count := get_log_call_count;
    counting_assert(call_count = expected_count, "Invalid report call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".", error);
  end verify_num_of_log_calls;

  function is_std_logic (
    constant c : character)
    return boolean is
  begin
    for i in 0 to 8 loop
      if c = std_logic'image(std_logic'val(i))(2) then
        return true;
      end if;
    end loop;
    return false;
  end;

  procedure apply_sequence (
    constant seq : in string;
    signal clk        : in  std_logic;
    signal data       : out std_logic;
    constant active_rising_clk_edge : in boolean := true) is
  begin
    for i in seq'range loop
      if is_std_logic(seq(i)) then
        data <= std_logic'value("'" & seq(i) & "'");
      end if;
      if i /= seq'right then
        if active_rising_clk_edge then
          wait until rising_edge(clk);
        else
          wait until falling_edge(clk);
        end if;
      end if;
    end loop;
  end procedure apply_sequence;

  procedure apply_sequence (
    constant seq : in string;
    signal clk        : in  std_logic;
    signal data       : out std_logic_vector;
    constant active_rising_clk_edge : in boolean := true) is
    variable i : natural := seq'left;
    variable delimiters : natural := 0;
    variable j : integer := 0;
    variable s : string(1 to 1);
  begin
    while i <= seq'right loop
      j := data'left;
      delimiters := 0;
      while (j <= data'high) and (j >= data'low) loop
        if data'ascending then
          if is_std_logic(seq(i + delimiters + j - data'left)) then
            data(j) <= std_logic'value("'" & seq(i + delimiters + j - data'left) & "'");
            j := j + 1;
          else
            delimiters := delimiters + 1;
          end if;
        else
          if is_std_logic(seq(i + delimiters - j + data'left)) then
            data(j) <= std_logic'value("'" & seq(i + delimiters - j + data'left) & "'");
            j := j - 1;
          else
            delimiters := delimiters + 1;
          end if;
        end if;
      end loop;
      i := i + data'length + delimiters;
      if i <= seq'right then
        if active_rising_clk_edge then
          wait until rising_edge(clk);
        else
          wait until falling_edge(clk);
        end if;
      end if;
    end loop;
  end procedure apply_sequence;

  procedure banner (
    constant s : in string) is
    variable dashes : string(1 to 256) := (others => '-');
  begin  -- banner
    report LF & dashes(s'range) & LF & s & LF & dashes(s'range);
  end banner;

  procedure print_test_result is
  begin
    banner("Test result");
    report "Number of assertions: " & natural'image(get_count(asserts));
    report "Number of errors: " & natural'image(get_count(unexpected_errors));
  end procedure print_test_result;

  procedure get_and_print_test_result (
    variable stat : out checker_stat_t) is
  begin
    reset_checker_stat; -- Normal checker stat doesn't contain real errors
    print_test_result;
    stat.n_checks := get_count(asserts);
    stat.n_failed := get_count(unexpected_errors);
    stat.n_passed := get_count(asserts) - get_count(unexpected_errors);
  end;

  function clock_edge (
    signal clk                : in std_logic;
    constant wait_rising_edge : in boolean := true)
    return boolean is
  begin
    if wait_rising_edge then
      return rising_edge(clk);
    else
      return falling_edge(clk);
    end if;
  end clock_edge;

end package body test_support;
