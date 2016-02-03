-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.lang_mock_types_pkg.all;
use vunit_lib.string_ops.all;
use std.textio.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_types.all;
use work.test_type_methods.all;

entity tb_logging is
  generic (output_path : string;
           runner_cfg : string);
end entity tb_logging;

architecture test_fixture of tb_logging is

  alias status is vunit_lib.log_pkg.info_high1[string, string, natural, string];
  signal test_component1_done, test_component2_done : boolean := false;
  shared variable n_asserts : shared_natural;
  shared variable n_errors : shared_natural;

  procedure counting_assert (
    constant expr : in boolean;
    constant msg  : in string := "";
    constant level : in severity_level := error) is
  begin
    add(n_asserts, 1);
    if not expr then
      assert false report msg severity level;
      add(n_errors, 1);
    end if;
  end procedure counting_assert;

  procedure verify_write_call (
    constant expected_count  : in natural;
    constant expected_string : in string) is
    variable call_count : natural;
    variable write_call_args : write_call_args_t;
    variable passed : boolean;
  begin
    call_count := get_write_call_count;
    counting_assert(call_count = expected_count, "Invalid write call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".", error);
    get_write_call_args(write_call_args);
    counting_assert(write_call_args.valid, "Write not called", error);
    passed := write_call_args.msg(1 to write_call_args.msg_length) = expected_string & LF;
    counting_assert(passed, "Wrong string. Got " &  write_call_args.msg(1 to write_call_args.msg_length) & " but expected " & expected_string & ".", error);
  end verify_write_call;

  procedure verify_num_of_write_calls (
    constant expected_count  : in natural) is
    variable call_count : natural;
  begin
    call_count := get_write_call_count;
    counting_assert(call_count = expected_count, "Invalid write call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".", error);
  end verify_num_of_write_calls;

  procedure verify_num_of_report_calls (
    constant expected_count  : in natural) is
    variable call_count : natural;
  begin
    call_count := get_report_call_count;
    counting_assert(call_count = expected_count, "Invalid report call count. Got " & natural'image(call_count) & " but was expecting " & natural'image(expected_count) & ".", error);
  end verify_num_of_report_calls;

  procedure verify_entry (
    constant actual   : in string;
    constant expected : in string) is
    variable actual_split, expected_split : lines_t;
  begin
    if (count(actual, ",") = 4) and (count(expected, ",") = 6) then
      actual_split := split(actual, ",");
      expected_split := split(expected, ",");
      counting_assert((actual_split(0).all = expected_split(0).all) and
                      (actual_split(1).all = expected_split(1).all) and
                      (actual_split(2).all = expected_split(2).all) and
                      (actual_split(3).all = expected_split(5).all) and
                      (actual_split(4).all = expected_split(6).all), "Error in entry. Got " & actual_split(0).all & "," &
                      actual_split(0).all & "," & actual_split(1).all & "," &
                      actual_split(2).all & "," & actual_split(3).all & "," &
                      actual_split(4).all & " but expected " & expected_split(0).all &
                      expected_split(1).all & expected_split(2).all &
                      expected_split(5).all & expected_split(6).all & ".", error);
    else
        counting_assert(actual = expected, "Error in entry. Got " & actual & " but expected " & expected & ".", error);
    end if;
  end procedure verify_entry;

  procedure verify_log_file (
    constant file_name : in string;
    variable entries   : inout line_vector) is
    file f : text;
    variable l : line;
    variable status : file_open_status;
  begin
    file_open(status, f, file_name, read_mode);
    counting_assert(status = open_ok, "Failed opening " & file_name & " (" & file_open_status'image(status) & ").", failure);
    if status = open_ok then
      for i in entries'range loop
        readline(f, l);
        verify_entry(l.all, entries(i).all);
      end loop;
    end if;
  end verify_log_file;
begin
  test_component1: process
  begin
    wait for 1 ns;
    info("I'm test component 1", ".tb_logging.test_component1.init");
    info("I'm not doing anything", ".tb_logging.test_component1.purpose");
    test_component1_done <= true;
    wait;
  end process test_component1;

  test_component2: process
  begin
    wait for 1 ns;
    info("I'm test component 2", ".tb_logging.test_component2.init");
    info("I'm logging time", ".tb_logging.test_component2.purpose");
    clock: for i in 1 to 3 loop
      info("Time is " & time'image(now), ".tb_logging.test_component2.clock.time");
      wait for 10 ns;
    end loop;
    test_component2_done <= true;
    wait;
  end process test_component2;

  test_runner : process
    variable l, l2, l3, uninitialized_logger, initialized_logger  : logger_t;
    variable entries : line_vector(1 to 30);
    variable f1, f2, f3, f4 : log_filter_t;
    variable lptr, lptr2 : lines_t;
    variable uninitialized_logger_cfg, initialized_logger_cfg : logger_cfg_t;
    variable uninitialized_logger_cfg_export, initialized_logger_cfg_export : logger_cfg_export_t;
    variable cnt : natural;
    variable report_call_args : report_call_args_t;
    variable n_asserts_value, n_errors_value : integer;
    procedure print_line_vector (
      variable l : lines_t) is
    begin
      for i in l'range loop
        report l(i).all;
      end loop;
    end procedure print_line_vector;
    procedure banner (
      constant s : in string) is
      variable dashes : string(1 to 256) := (others => '-');
    begin
      write(output, dashes(s'range) & LF & s & LF & dashes(s'range) & LF);
    end banner;
  begin
    logger_init(file_name => output_path & "log.csv");
    -- Report equivalent
    banner("Verify report equivalent");
    log("Hello World");
    verify_write_call(1, "Hello World");
    -- Log with level
    banner("Verify log with level");
    log("This is a warning", warning);
    verify_write_call(2, "This is a warning");

    -- Convenience functions
    banner("Verify log level convenience procedures");
    warning("This is a potentially harmful situation");
    verify_write_call(3, "This is a potentially harmful situation");
    error("An error but design may continue to work");
    verify_write_call(4, "An error but design may continue to work");
    failure("Very severe condition, likely to crash");
    verify_write_call(5, "Very severe condition, likely to crash");

    info("High-level internal info, typically progress at a high level (startup, shutdown,...)");
    verify_write_call(6, "High-level internal info, typically progress at a high level (startup, shutdown,...)");
    debug("Medium-level internal information, typically for debugging");
    verify_write_call(7, "Medium-level internal information, typically for debugging");
    verbose("Low-level internal info");
    verify_write_call(8, "Low-level internal info");

    -- Custom levels
    banner("Verify custom levels");
    logger_init(display_format => level, file_name => output_path & "log.csv");
    log("This is a status message", info_high1);
    verify_write_call(9, "INFO_HIGH1: This is a status message");
    info_high1("This is a status message");
    verify_write_call(10, "INFO_HIGH1: This is a status message");
    rename_level(info_high1, "status");
    status("This is a status message");
    verify_write_call(11, "STATUS: This is a status message");
    logger_init(display_format => raw, file_name => output_path & "log.csv");

    -- Identify source of log
    banner("Verify log with specified source");
    log("This is a warning from the temperature sensor", warning, "temperature_sensor");
    verify_write_call(12, "This is a warning from the temperature sensor");
    warning("This is a warning from the temperature sensor", "temperature_sensor");
    verify_write_call(13, "This is a warning from the temperature sensor");
    temperature_sensor: warning("This is a warning from the temperature sensor", ".tb_logging.temperature_sensor");
    verify_write_call(14, "This is a warning from the temperature sensor");

    -- Two handlers and two formatters
    banner("Verify file handler and verbose formatter");
    temp_sensor: logger_init(".tb_logging.temp_sensor", output_path & "temperature_sensor.csv", verbose, verbose_csv);

    info("High temp");
    verify_write_call(15, time'image(0 ps) & ": INFO in .tb_logging.temp_sensor (tb_logging.vhd:212): High temp");
    write(entries(1), string'("0," & time'image(0 ps) & ",info,tb_logging.vhd,212,.tb_logging.temp_sensor,High temp"));

    -- Different loggers with different configurations
    banner("Verify custom loggers");
    humidity_sensor: logger_init(l, ".tb_logging.humidity_sensor", output_path & "humidity_sensor.csv", level, raw);

    warning(l, "High humidity");
    verify_write_call(16, "WARNING: High humidity");
    write(entries(3), string'("High humidity"));
    verify_log_file(output_path & "humidity_sensor.csv", entries(3 to 3));

    -- Level filters
    banner("Verify level filters");
    stop_level(l, warning, display_handler, f1);
    stop_level(l, (debug, verbose), display_handler, f2);

    debug(l,"Debug should not pass");
    verify_num_of_write_calls(16);
    verbose(l,"Verbose should not pass");
    verify_num_of_write_calls(16);
    warning(l,"Warning should not pass");
    verify_num_of_write_calls(16);
    error(l,"Error should pass");
    verify_write_call(17, "ERROR: Error should pass");
    remove_filter(l,f2);
    debug(l,"Debug should pass");
    verify_write_call(18, "DEBUG: Debug should pass");
    verbose(l,"Verbose should pass");
    verify_write_call(19, "VERBOSE: Verbose should pass");
    warning(l,"Warning should not pass");
    verify_num_of_write_calls(19);
    error(l,"Error should pass");
    verify_write_call(20, "ERROR: Error should pass");
    remove_filter(l,f1);
    warning(l,"Warning should pass");
    verify_write_call(21, "WARNING: Warning should pass");
    pass_level(l, (debug, verbose), display_handler, f1);
    debug(l,"Debug should pass");
    verify_write_call(22, "DEBUG: Debug should pass");
    verbose(l,"Verbose should pass");
    verify_write_call(23, "VERBOSE: Verbose should pass");
    warning(l,"Warning should not pass");
    verify_num_of_write_calls(23);
    error(l,"Error should not pass");
    verify_num_of_write_calls(23);
    error("Error on default logger should pass");
    verify_write_call(24, time'image(0 ps) & ": ERROR in .tb_logging.temp_sensor (tb_logging.vhd:259): Error on default logger should pass");
    write(entries(2), string'("1," & time'image(0 ps) & ",error,tb_logging.vhd,259,.tb_logging.temp_sensor,Error on default logger should pass"));
    verify_log_file(output_path & "temperature_sensor.csv", entries(1 to 2));

    stop_level(l, warning, file_handler, f2);
    warning(l,"Warning should not pass to file");
    verify_num_of_write_calls(24);
    error(l,"Error should pass to file");
    verify_num_of_write_calls(24);
    remove_filter(l, f1);
    remove_filter(l, f2);

    write(entries(4), string'("Debug should not pass"));
    write(entries(5), string'("Verbose should not pass"));
    write(entries(6), string'("Warning should not pass"));
    write(entries(7), string'("Error should pass"));
    write(entries(8), string'("Debug should pass"));
    write(entries(9), string'("Verbose should pass"));
    write(entries(10), string'("Warning should not pass"));
    write(entries(11), string'("Error should pass"));
    write(entries(12), string'("Warning should pass"));
    write(entries(13), string'("Debug should pass"));
    write(entries(14), string'("Verbose should pass"));
    write(entries(15), string'("Warning should not pass"));
    write(entries(16), string'("Error should not pass"));
    write(entries(17), string'("Error should pass to file"));
    verify_log_file(output_path & "humidity_sensor.csv", entries(3 to 17));

    -- Simple source filters
    banner("Verify simple source filters");
    logger_init(l2, "pressure_sensor", output_path & "pressure_sensor.csv", raw, verbose_csv);

    stop_source(l2, "temperature_sensor", display_handler, f1);
    error(l2,"Error should pass");
    verify_write_call(25, "Error should pass");

    stop_level(l2, warning, display_handler, f2);
    error(l2,"Error should pass");
    verify_write_call(26, "Error should pass");

    stop_source(l2, "pressure_sensor", display_handler, f3);
    error(l2,"Error should not pass");
    verify_num_of_write_calls(26);
    remove_filter(l2, f1);
    remove_filter(l2, f3);
    pass_source(l2, "pressure_sensor", (display_handler, file_handler), f3);
    error(l2,"Error should not pass", "some_sensor");
    verify_num_of_write_calls(26);
    rename_level(l2, error, "test_level");
    error(l2,"Error should pass");
    verify_num_of_write_calls(27);
    rename_level(l2, error, "error");
    remove_filter(l2, f3);

    write(entries(18), string'("2," & time'image(0 ps) & ",error,tb_logging.vhd,293,pressure_sensor,Error should pass"));
    write(entries(19), string'("3," & time'image(0 ps) & ",error,tb_logging.vhd,297,pressure_sensor,Error should pass"));
    write(entries(20), string'("4," & time'image(0 ps) & ",error,tb_logging.vhd,301,pressure_sensor,Error should not pass"));
    write(entries(21), string'("5," & time'image(0 ps) & ",test_level,tb_logging.vhd,309,pressure_sensor,Error should pass"));
    verify_log_file(output_path & "pressure_sensor.csv", entries(18 to 21));

    -- Source level filters
    banner("Verify source level filters");
    logger_init(l2, "pressure_sensor", output_path & "pressure_sensor.csv", raw, verbose_csv);

    stop_source_level(l2, "temperature_sensor", error, display_handler, f1);
    error(l2,"Error should pass");
    verify_write_call(28, "Error should pass");

    stop_source_level(l2, "pressure_sensor", warning, display_handler, f2);
    error(l2,"Error should pass");
    verify_write_call(29, "Error should pass");

    stop_source_level(l2, "pressure_sensor", error, display_handler, f3);
    error(l2,"Error should not pass");
    verify_num_of_write_calls(29);
    remove_filter(l2, f1);
    remove_filter(l2, f2);
    remove_filter(l2, f3);
    pass_source_level(l2, "pressure_sensor", error, (display_handler, file_handler), f3);
    error(l2,"Error should not pass", "some_sensor");
    warning(l2,"Error should not pass");
    error(l2,"Error should pass");
    remove_filter(l2, f3);

    write(entries(22), string'("6," & time'image(0 ps) & ",error,tb_logging.vhd,325,pressure_sensor,Error should pass"));
    write(entries(23), string'("7," & time'image(0 ps) & ",error,tb_logging.vhd,329,pressure_sensor,Error should pass"));
    write(entries(24), string'("8," & time'image(0 ps) & ",error,tb_logging.vhd,333,pressure_sensor,Error should not pass"));
    write(entries(25), string'("9," & time'image(0 ps) & ",error,tb_logging.vhd,341,pressure_sensor,Error should pass"));
    verify_log_file(output_path & "pressure_sensor.csv", entries(22 to 25));

    -- Hierarchical source filters
    banner("Verify hierarchical source filters");
    logger_init("test_components", display_format => verbose_csv, file_format => verbose_csv, file_name => output_path & "log.csv");
    stop_source(".tb_logging.test_component1", (display_handler, file_handler), f1);

    wait on test_component1_done, test_component2_done until test_component1_done and test_component2_done;

    write(entries(26), string'("10," & time'image(1000 ps) & ",info,tb_logging.vhd,127,.tb_logging.test_component2.init,I'm test component 2"));
    write(entries(27), string'("11," & time'image(1000 ps) & ",info,tb_logging.vhd,128,.tb_logging.test_component2.purpose,I'm logging time"));
    write(entries(28), string'("12," & time'image(1000 ps) & ",info,tb_logging.vhd,130,.tb_logging.test_component2.clock.time,Time is " & time'image(1000 ps)));
    write(entries(29), string'("13," & time'image(11000 ps) & ",info,tb_logging.vhd,130,.tb_logging.test_component2.clock.time,Time is " & time'image(11000 ps)));
    write(entries(30), string'("14," & time'image(21000 ps) & ",info,tb_logging.vhd,130,.tb_logging.test_component2.clock.time,Time is " & time'image(21000 ps)));
    verify_log_file(output_path & "log.csv", entries(26 to 30));

    -- get_logger_cfg
    banner("Verify that get_logger_cfg can be called on an uninitialized logger");
    get_logger_cfg(uninitialized_logger, uninitialized_logger_cfg);
    counting_assert(not uninitialized_logger_cfg.log_file_is_initialized);
    get_logger_cfg(uninitialized_logger, uninitialized_logger_cfg_export);
    counting_assert(not uninitialized_logger_cfg_export.log_file_is_initialized);

    -- Verify break level
    banner("Verify that log entries with levels greater than or equal to the break level stops the simulation but lower levels don't.");
    logger_init(file_name => output_path & "log.csv");
    cnt := get_report_call_count;
    log("Should not break", failure_low1);
    verify_num_of_report_calls(cnt);
    log("Should break", failure);
    get_report_call_args(report_call_args);
    verify_num_of_report_calls(cnt + 1);
    counting_assert(report_call_args.valid);
    counting_assert(report_call_args.msg_length = 0);
    counting_assert(report_call_args.level = failure);
    logger_init(stop_level => highest_level, file_name => output_path & "log.csv");
    cnt := get_report_call_count;
    log("Should not break", failure_high2);
    verify_num_of_report_calls(cnt);
    for l in log_level_t'pos(failure_high2) to log_level_t'pos(verbose_low1) loop
      logger_init(stop_level => log_level_t'val(l), file_name => output_path & "log.csv");
      cnt := get_report_call_count;
      log("Should not break", log_level_t'rightof(log_level_t'val(l)));
      verify_num_of_report_calls(cnt);
      log("Should break", log_level_t'val(l));
      get_report_call_args(report_call_args);
      verify_num_of_report_calls(cnt + 1);
      counting_assert(report_call_args.valid);
      counting_assert(report_call_args.msg_length = 0);
      counting_assert(report_call_args.level = failure);
    end loop;
    logger_init(stop_level => verbose_low2, file_name => output_path & "log.csv");
    cnt := get_report_call_count;
    log("Should break", verbose_low2);
    get_report_call_args(report_call_args);
    verify_num_of_report_calls(cnt + 1);
    counting_assert(report_call_args.valid);
    counting_assert(report_call_args.msg_length = 0);
    counting_assert(report_call_args.level = failure);

    -- Verify configuration export
    banner("Verify that all entries of the logger configuration are exported correctly.");
    logger_init("my_src", output_path & "file.csv", verbose_csv, raw, error, ';', true);
    get_logger_cfg(initialized_logger_cfg);
    counting_assert(initialized_logger_cfg.log_default_src.all = "my_src");
    counting_assert(initialized_logger_cfg.log_file_name.all = output_path & "file.csv");
    counting_assert(initialized_logger_cfg.log_display_format = verbose_csv);
    counting_assert(initialized_logger_cfg.log_file_format = raw);
    counting_assert(initialized_logger_cfg.log_file_is_initialized);
    counting_assert(initialized_logger_cfg.log_stop_level = error);
    counting_assert(initialized_logger_cfg.log_separator = ';');

    get_logger_cfg(initialized_logger_cfg_export);
    counting_assert(initialized_logger_cfg_export.log_default_src(1 to 6) = "my_src");
    counting_assert(initialized_logger_cfg_export.log_default_src_length = 6);
    counting_assert(initialized_logger_cfg_export.log_file_name(1 to 8+output_path'length) = output_path & "file.csv");
    counting_assert(initialized_logger_cfg_export.log_file_name_length = 8+output_path'length);
    counting_assert(initialized_logger_cfg_export.log_display_format = verbose_csv);
    counting_assert(initialized_logger_cfg_export.log_file_format = raw);
    counting_assert(initialized_logger_cfg_export.log_file_is_initialized);
    counting_assert(initialized_logger_cfg_export.log_stop_level = error);
    counting_assert(initialized_logger_cfg_export.log_separator = ';');

    logger_init(initialized_logger, "my_src2", output_path & "file2.csv", off, verbose_csv, warning, ':', true);
    get_logger_cfg(initialized_logger, initialized_logger_cfg);
    counting_assert(initialized_logger_cfg.log_default_src.all = "my_src2");
    counting_assert(initialized_logger_cfg.log_file_name.all = output_path & "file2.csv");
    counting_assert(initialized_logger_cfg.log_display_format = off);
    counting_assert(initialized_logger_cfg.log_file_format = verbose_csv);
    counting_assert(initialized_logger_cfg.log_file_is_initialized);
    counting_assert(initialized_logger_cfg.log_stop_level = warning);
    counting_assert(initialized_logger_cfg.log_separator = ':');

    get_logger_cfg(initialized_logger, initialized_logger_cfg_export);
    counting_assert(initialized_logger_cfg_export.log_default_src(1 to 7) = "my_src2");
    counting_assert(initialized_logger_cfg_export.log_default_src_length = 7);
    counting_assert(initialized_logger_cfg_export.log_file_name(1 to 9+output_path'length) = output_path & "file2.csv");
    counting_assert(initialized_logger_cfg_export.log_file_name_length = 9+output_path'length);
    counting_assert(initialized_logger_cfg_export.log_display_format = off);
    counting_assert(initialized_logger_cfg_export.log_file_format = verbose_csv);
    counting_assert(initialized_logger_cfg_export.log_file_is_initialized);
    counting_assert(initialized_logger_cfg_export.log_stop_level = warning);
    counting_assert(initialized_logger_cfg_export.log_separator = ':');

    banner("Test result");
    get(n_asserts, n_asserts_value);
    get(n_errors, n_errors_value);
    write(output, "Number of assertions: " & integer'image(n_asserts_value) & LF);
    write(output, "Number of errors: " & integer'image(n_errors_value) & LF);

    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
    wait;
  end process;
end test_fixture;
