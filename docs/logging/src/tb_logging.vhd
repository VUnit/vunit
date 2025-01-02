-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

entity tb_logging is
  generic(runner_cfg : string);
end entity;

architecture doc of tb_logging is
  constant level_file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "level_log.txt"), format => level, use_color => true);
  constant verbose_file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "verbose_log.txt"), use_color => true);
  constant log_handlers : log_handler_vec_t := (display_handler, level_file_handler, verbose_file_handler);

  --start_snippet logger_declaration
  constant my_logger : logger_t := get_logger("system0:uart0");
  --end_snippet logger_declaration

  signal clk : std_logic := '0';

  -- start_snippet another_convenience_procedure
  procedure my_convenience_procedure(
    -- Custom parameters ...

    line_num : natural := 0;
    file_name : string := "") is
  begin
    -- Some code ...
    info("Some message", line_num => line_num, file_name => file_name);
    -- Some code ...
  end procedure my_convenience_procedure;
  -- end_snippet another_convenience_procedure

begin
  main : process is
    -- start_snippet logger_from_id
    constant my_id : id_t := get_id("system0:uart0");
    constant my_logger : logger_t := get_logger(my_id);
    -- end_snippet logger_from_id

    -- start_snippet custom_log_level
    constant license_info : log_level_t := new_log_level("license", fg => red, bg => yellow, style => bright);
    -- end_snippet custom_log_level

    file my_file_object : text;
    variable status : file_open_status;
    variable logger : logger_t;

    -- start_snippet convenience_procedure
    procedure my_convenience_procedure(
      -- start_folding -- Parameters ...
      a : bit
      -- end_folding -- Parameters ...
    ) is
    begin
      -- Some code ...
      info("Some message", path_offset => 1);
      -- Some code ...
    end procedure my_convenience_procedure;
    -- end_snippet convenience_procedure

  begin
    test_runner_setup(runner, runner_cfg);

    for idx in log_handlers'range loop
      hide_all(log_handlers(idx));
      show(log_handlers(idx), (info, warning, error, failure));
      hide_all(get_logger("runner"), log_handlers(idx));
    end loop;
    set_log_handlers(root_logger, log_handlers);

    while test_suite loop
      if run("Document architecture") then
        -- start_snippet log_call
        info("Hello world");
        -- end_snippet log_call
        -- start_snippet log_call_with_logger
        info(my_logger, "Hello world");
        -- end_snippet log_call_with_logger

      elsif run("Document log levels") then
        mock(default_logger, failure);
        mock(default_logger, error);

        -- start_snippet standard_log_levels
        -- Visible to display by default
        failure("Fatal error, there is most likely no point in going further");
        error("An error but we could still keep running for a while");
        warning("A warning");
        info("Informative message for very useful public information");

        -- Not visible by default
        pass("Message from a passing check");
        debug("Debug message for seldom useful or internal information");
        trace("Trace messages only used for tracing program flow");
        -- end_snippet standard_log_levels

        check_log(default_logger, "Fatal error, there is most likely no point in going further", failure);
        check_log(default_logger, "An error but we could still keep running for a while", error);
        unmock(default_logger);

        -- start_snippet conditional_log
        warning_if(True, "A warning happened");
        warning_if(False, "A warning did not happen");

        -- There are also variants for error and failure as well as with
        -- non-default logger argument.
        -- end_snippet conditional_log

        show(display_handler, license_info);
        -- start_snippet log_call_with_custom_level
        log("Mozilla Public License, v. 2.0.", license_info);
        log(my_logger, "Mozilla Public License, v. 2.0.", license_info);
        -- end_snippet log_call_with_custom_level

      elsif run("Document set_format") then
        -- start_snippet set_format
        set_format(display_handler, level);
        info("Hello world");
        -- end_snippet set_format

      elsif run("Document verbose format") then
        set_format(display_handler, verbose, true, log_time_unit => ps, n_log_time_decimals => 0);
        set_format(verbose_file_handler, verbose, true, log_time_unit => ps, n_log_time_decimals => 0);
        wait for 123456 ps;
        warning("Warnings are yellow");

      elsif run("Document log_time_unit") then
        set_stop_count(get_logger("check"), error, 2);
        set_format(display_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 3);
        set_format(verbose_file_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 3);
        wait for 123456 ps;
        check(false, "Errors are red");

        -- Delete error to enable capture of log output
        reset_log_count(get_logger("check"), error);

      elsif run("Document full_time_resolution") then
        set_stop_count(get_logger("check"), failure, 2);
        set_format(display_handler, verbose, true, log_time_unit => us, n_log_time_decimals => 6);
        set_format(verbose_file_handler, verbose, true, log_time_unit => us, n_log_time_decimals => 6);
        wait for 123456 ps;
        check(false, "Failures are even more red", level => failure);

        -- Delete error to enable capture of log output
        reset_log_count(get_logger("check"), failure);

      elsif run("Document fix decimals") then
        show(display_handler, pass);
        show(verbose_file_handler, pass);
        set_format(display_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 2);
        set_format(verbose_file_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 2);
        wait for 123456 ps;
        pass("Passes are green");

      elsif run("Document stopping simulation") then
        -- start_snippet stopping_simulation
        -- Allow 10 errors from my_logger and its children
        set_stop_count(my_logger, error, 10);

        -- Disable stop on errors from my_logger and its children
        disable_stop(my_logger, error);

        -- Short hand for stopping on error and failure but not warning globally
        set_stop_level(error);

        -- Short hand for stopping on warning, error and failure for specific logger
        set_stop_level(get_logger("my_library:my_component"), warning);
        -- end_snippet stopping_simulation

      elsif run("Document print procedure") then
        -- start_snippet print
        print("Message to stdout");
        print("Append this message to an existing file or create a new file if it doesn't exist", "path/to/file");
        print("Create new file with this message", "path/to/file", write_mode);
        -- end_snippet print
        file_open(status, my_file_object, "path/to/file", append_mode);
        -- start_snippet print_to_open_file
        print("Message to file object", my_file_object);
        -- end_snippet print_to_open_file

      elsif run("Document log visability") then
        -- start_snippet log_visibility
        -- Disable all logging to the display.
        hide_all(display_handler);

        -- Show debug log level of system0 logger to the display
        show(get_logger("system0"), display_handler, debug);

        -- Show all logging from the uart module in system0 to the display
        show_all(get_logger("system0:uart"), display_handler);

        -- Hide all debug output to display handler
        hide(display_handler, debug);
        -- end_snippet log_visibility

      elsif run("Document mocking") then
        -- start_snippet mocking
        logger := get_logger("my_library");
        mock(logger, failure);

        -- start_folding -- Code to trigger an error
        failure(logger, "Some error message");
        -- end_folding -- Code to trigger an error

        -- Verify that the expected error message has been produced
        check_only_log(logger, "Some error message", failure);
        unmock(logger);
        -- end_snippet mocking

        -- start_snippet mock_queue_length
        logger := get_logger("my_library");
        mock(logger, failure);

        -- start_folding -- Code to trigger the error
        failure(logger, "Some error message");
        -- end_folding -- Code to trigger the error

        wait until mock_queue_length > 0 and rising_edge(clk);
        check_only_log(logger, "Some error message", failure);
        unmock(logger);
        -- end_snippet mock_queue_length

      elsif run("Document disabled logs") then
        -- start_snippet disabled_log
        -- Irrelevant warning
        disable(get_logger("memory_ip:timing_check"), warning);
        -- end_snippet disabled_log

      elsif run("Document log location") then
        set_stop_count(get_logger("check"), error, 2);
        set_format(display_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 3);
        set_format(verbose_file_handler, verbose, true, log_time_unit => auto_time_unit, n_log_time_decimals => 3);
        wait for 1260 ns;
        check_equal(15, 16, result("for packet length"), line_num => 73, file_name => "receiver.vhd");

        -- Delete error to enable capture of log output
        reset_log_count(get_logger("check"), error);

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  clk <= not clk after 5 ns;

end architecture;
