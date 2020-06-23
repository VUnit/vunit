-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com
-------------------------------------------------------------------------------
-- This testbench verifies deprecated interfaces
-------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.log_deprecated_pkg.all;
use work.core_pkg.all;
use work.test_support_pkg.all;

entity tb_log_deprecated is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_log_deprecated is
begin
  test_runner : process
    variable my_logger, my_logger2, uninitialized_logger : logger_t;
    constant deprecated_msg : string :=
      "Using deprecated procedure logger_init. Using best effort mapping to contemporary functionality";

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      logger_init(my_logger);

      if run("Test log") then
        set_format(display_handler, format => raw);

        mock(default_logger);
        log("Hello world");
        check_only_log(default_logger, "Hello world", info);
        unmock(default_logger);

        mock_core_failure;
        log(uninitialized_logger, "Hello world");
        check_and_unmock_core_failure("Attempt to log to uninitialized logger");

      elsif run("Test initializing logger") then
        mock(default_logger);
        logger_init(my_logger2);
        check_log(default_logger, deprecated_msg, warning);
        check_log(default_logger, "Empty string logger names not supported. Using ""anonymous1""",  warning);
        unmock(default_logger);

        assert_equal(get_name(my_logger2), "anonymous1");

        assert_equal(num_log_handlers(my_logger2), 2);
        assert(get_file_name(get_file_handler(my_logger2)) = "log.csv");
        assert(get_file_name(get_display_handler(my_logger2)) = stdout_file_name);

        assert(get_display_handler(my_logger2) /= get_display_handler(default_logger));
        assert(get_file_handler(my_logger2) /= get_file_handler(default_logger));
        check_format(my_logger2, get_display_handler(my_logger2), raw);
        check_format(my_logger2, get_file_handler(my_logger2), off);

      elsif run("Test changing logger name") then
        mock(default_logger);
        mock_core_failure;
        logger_init(my_logger, default_src => "my_logger");
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing logger name is not supported");
        unmock(default_logger);
        unmock_core_failure;
        assert_equal(get_name(my_logger), "anonymous0");

        mock(default_logger);
        mock_core_failure;
        logger_init(default_src => "my_logger");
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing logger name is not supported");
        unmock(default_logger);
        unmock_core_failure;
        assert_equal(get_name(default_logger), "default");

      elsif run("Test changing file name") then
        mock(default_logger);
        logger_init(my_logger, file_name => "my_logger.csv");
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        assert_equal(get_file_name(get_file_handler(my_logger)), "my_logger.csv");

        mock(default_logger);
        logger_init(file_format => csv, file_name => "my_logger.csv");
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        assert_equal(get_file_name(get_file_handler(default_logger)), "my_logger.csv");

      elsif run("Test changing display format") then
        mock(default_logger);
        logger_init(my_logger, display_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(my_logger, get_display_handler(my_logger), verbose);

        mock(default_logger);
        logger_init(display_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(default_logger, get_display_handler(default_logger), verbose);

      elsif run("Test changing file format") then
        mock(default_logger);
        logger_init(my_logger, file_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(my_logger, get_file_handler(my_logger), verbose);

        mock(default_logger);
        logger_init(file_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(default_logger, get_file_handler(default_logger), verbose);

      elsif run("Test changing stop level") then
        mock(default_logger);
        logger_init(my_logger, stop_level => error);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);

        mock(default_logger);
        logger_init(stop_level => error);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);

      elsif run("Test changing separator") then
        mock_core_failure;
        mock(default_logger);
        logger_init(my_logger, separator => ';');
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing CSV separator is not supported");
        unmock(default_logger);
        unmock_core_failure;

        mock(default_logger);
        mock_core_failure;
        logger_init(separator => ';');
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing CSV separator is not supported");
        unmock(default_logger);
        unmock_core_failure;

      elsif run("Test changing append") then
        mock_core_failure;
        mock(default_logger);
        logger_init(my_logger, append => true);
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Appending new log to existing file is not supported");
        unmock(default_logger);
        unmock_core_failure;

        mock_core_failure;
        mock(default_logger);
        logger_init(append => true);
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Appending new log to existing file is not supported");
        unmock(default_logger);
        unmock_core_failure;

      elsif run("Test verbose procedures and log level") then
        mock(default_logger);
        verbose("hello", 17, "foo.vhd");
        check_log(default_logger, "Mapping deprecated procedure verbose to trace", warning);
        check_log(default_logger, "hello", trace, 0 ns, 17, "foo.vhd");
        unmock(default_logger);

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
