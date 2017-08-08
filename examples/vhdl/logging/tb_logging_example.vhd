-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_logging_example is
  generic (runner_cfg : string);
end entity;

architecture test of tb_logging_example is
begin

  example_process: process is
    variable my_logger : logger_t := get_logger("logging_example.my_logger");
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

    -- Setting the log level of the parent automatically sets it for all children
    set_log_level(display_handler, get_logger("logging_example"), warning);
    info(my_logger, "This will not be shown on stdout");

    -- The log format can be changed
    set_format(display_handler, raw);
    info("Raw format");

    set_format(display_handler, csv);
    info("CSV format");

    -- We disable the simulation stop to show error and failure
    disable_stop;
    set_format(display_handler, level, use_color => true);
    info("Level format");
    warning("Level format");
    error("Level format");
    failure("Level format");

    set_format(display_handler, verbose, use_color => true);
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
