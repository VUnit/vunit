-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.print_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_handler_pkg.all;
use vunit_lib.run_pkg.all;

use std.textio.all;

entity tb_logging_example is
  generic (runner_cfg : string);
end entity;

architecture test of tb_logging_example is
begin

  example_process: process is
    variable my_logger : logger_t := get_logger("logging_example:my_logger");
    constant file_name : string := output_path(runner_cfg) & "log.csv";

    file fptr : text;
    variable status : file_open_status;
  begin
    test_runner_setup(runner, runner_cfg);

    -- An informative log to the the default logger
    info("Hello world");

    -- Log messages can also be multi line
    info("Hello" & LF & "world");

    -- Trace and debug messages are not written to the display by default
    debug("not visible");
    trace("not visible");

    -- Custom loggers can also be used
    info(my_logger, "Message to my_logger");

    -- Loggers have hierarchy
    assert get_parent(my_logger) = get_logger("logging_example");
    assert get_child(get_logger("logging_example"), 0) = my_logger;

    -- Log visibility settings are inherited by all children
    show(get_parent(my_logger), display_handler, debug);
    debug(my_logger, "This will be shown on stdout");
    debug(get_parent(my_logger), "This will be shown on stdout");
    hide(my_logger, display_handler, debug);
    debug(my_logger, "This is no longer shown on stdout");
    debug(get_parent(my_logger), "This is still shown on stdout");

    -- The simulation time format can be changed
    wait for 1500 ns;
    info("Default time format using the simulator's native resolution as unit");
    set_format(display_handler, use_color => true, log_time_unit => ns);
    info("Changing to ns");
    set_format(
      display_handler, use_color => true, log_time_unit => ns, n_log_time_decimals => full_time_resolution
    );
    info("With decimals to cover the full simulator resolution");
    set_format(
      display_handler, use_color => true, log_time_unit => auto_time_unit, n_log_time_decimals => full_time_resolution
    );
    info("The unit can be automatically adjusted to keep the numerical value in the [0, 1000) range");
    set_format(
      display_handler, use_color => true, log_time_unit => auto_time_unit, n_log_time_decimals => 2
    );
    info("The number of decimals can be a fix value");
    set_format(
      display_handler, use_color => true, log_time_unit => native_time_unit, n_log_time_decimals => 0
    );
    info("Back to the native format");

    -- The overall log format can also be changed
    set_format(display_handler, raw);
    info("Raw format");

    set_format(display_handler, csv);
    info("CSV format");

    -- The print procedure is independent of logging
    print("Print on stdout");
    print("Print on file using file name", file_name);
    file_open(status, fptr, file_name, append_mode);
    assert status = open_ok report "Failed to open file " & file_name severity failure;
    print("Print on file using file object", fptr);
    file_close(fptr);

    -- We disable the simulation stop to show error and failure
    disable_stop(default_logger, failure);
    disable_stop(default_logger, error);
    show_all(display_handler);
    set_format(display_handler, level, use_color => true);
    trace("Level format");
    debug("Level format");
    info("Level format");
    warning("Level format");
    error("Level format");
    failure("Level format");

    set_format(display_handler, verbose, use_color => true);
    trace("Verbose format");
    debug("Verbose format");
    info("Verbose format");
    warning("Verbose format");
    error("Verbose format");
    failure("Verbose format");

    -- Loggers can also be mocked
    mock(my_logger);
    failure(my_logger, "message");
    check_only_log(my_logger, "message", failure);
    unmock(my_logger);

    -- Conditionall logging is also possible
    warning_if(True, "A warning happened");
    warning_if(False, "A warning did not happen");

    -- Any log to error or failure causes test failure so we reset those levels
    reset_log_count(default_logger, error);
    reset_log_count(default_logger, failure);

    test_runner_cleanup(runner);
    wait;
  end process;



end architecture;
