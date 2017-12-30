-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

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

    file fptr : text;
    variable status : file_open_status;
  begin
    test_runner_setup(runner, runner_cfg);

    -- An informative log to the the default logger
    info("Hello world");

    -- Log messages can also be multi line
    info("Hello" & LF & "world");

    -- Verbose and debug messages are not written to the display by default
    debug("not visible but found in log.csv file");
    verbose("not visible");

    -- Custom loggers can also be used
    info(my_logger, "Message to my_logger");

    -- Loggers have hierarchy
    assert get_parent(my_logger) = get_logger("logging_example");
    assert get_child(get_logger("logging_example"), 0) = my_logger;

    -- Log filter settings are inherited by all children
    set_log_level(get_parent(my_logger), display_handler, debug);
    verbose(my_logger, "This will not be shown on stdout");
    warning(my_logger, "This will be shown on stdout");
    disable(my_logger, display_handler, (warning, debug));
    warning(my_logger, "This is no longer shown on stdout");
    warning(get_parent(my_logger), "This is still shown on stdout");

    -- The log format can be changed
    set_format(display_handler, raw);
    info("Raw format");

    set_format(display_handler, csv);
    info("CSV format");

    -- The print procedure is independent of logging
    print("Print on stdout");
    print("Print on file using file name", get_file_name(file_handler));
    file_open(status, fptr, get_file_name(file_handler), append_mode);
    assert status = open_ok report "Failed to open file " & get_file_name(file_handler) severity failure;
    print("Print on file using file object", fptr);
    file_close(fptr);

    -- We disable the simulation stop to show error and failure
    disable_stop;
    enable_all(display_handler);
    set_format(display_handler, level, use_color => true);
    verbose("Level format");
    debug("Level format");
    info("Level format");
    warning("Level format");
    error("Level format");
    failure("Level format");

    set_format(display_handler, verbose, use_color => true);
    verbose("Verbose format");
    debug("Verbose format");
    info("Verbose format");
    warning("Verbose format");
    error("Verbose format");
    failure("Verbose format");
    set_stop_level(error);

    -- Loggers can also be mocked
    mock(my_logger);
    failure(my_logger, "message");
    check_only_log(my_logger, "message", failure);
    unmock(my_logger);

    -- Any log to error or failure causes test failure so we reset those levels
    reset_log_count(default_logger, error);
    reset_log_count(default_logger, failure);
    reset_log_count(my_logger, failure);

    test_runner_cleanup(runner);
    wait;
  end process;



end architecture;
