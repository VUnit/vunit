-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com
-------------------------------------------------------------------------------
-- This testbench verifies deprecated interfaces
-------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.run_pkg.all;

use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_handler_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_deprecated_pkg.all;
use vunit_lib.log_deprecated_pkg.all;
use vunit_lib.core_pkg.all;
use vunit_lib.ansi_pkg.all;
library logging_tb_lib;
use logging_tb_lib.test_support_pkg.all;

entity tb_deprecated is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_deprecated is
begin
  test_runner : process
    variable my_checker : checker_t;
    variable my_checker_logger : logger_t;
    variable almost_failure : log_level_t := new_log_level("almost_failure", failure - 1);
    variable found_errors : boolean;

    constant deprecated_logger_init_msg : string :=
      "Using deprecated procedure logger_init. Using best effort mapping to contemporary functionality";
    constant deprecated_checker_init_msg : string :=
      "Using deprecated procedure checker_init. Using best effort mapping to contemporary functionality";
    constant empty_msg : string :=
      "Empty string checker names not supported. Using ""anonymous0""";

    procedure check_warnings(is_new : boolean) is
    begin
      check_log(default_logger, deprecated_checker_init_msg,  warning);
      if is_new then
        check_log(default_logger, empty_msg,  warning);
      end if;
      check_log(default_logger, deprecated_logger_init_msg,  warning);
    end procedure check_warnings;

    procedure check_checker_init(checker : checker_t; name : string; is_new : boolean) is
      variable logger : logger_t;
      variable checker_int : checker_t := checker;
    begin
      check_warnings(is_new);

      assert_true(get_default_log_level(checker_int) = error);

      logger := get_logger(checker_int);
      assert_equal(get_name(get_logger(checker_int)), name);

      assert_equal(num_log_handlers(logger), 2);
      assert_equal(get_file_name(get_file_handler(logger)), "error.csv");
      assert_equal(get_file_name(get_display_handler(logger)), stdout_file_name);

      check_format(logger, get_display_handler(logger), level);
      check_format(logger, get_file_handler(logger), off);

      check_stop_level(logger, almost_failure, failure);
    end;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      mock(default_logger);

      if run("Test initializing checker") then
        checker_init(my_checker);
        check_checker_init(my_checker, "anonymous0", true);

        checker_init;
        check_checker_init(default_checker, "check", false);
      elsif run("Test changing checker default level") then
        checker_init(my_checker);
        check_warnings(true);
        checker_init(my_checker, default_level => failure);
        check_warnings(false);
        assert_true(get_default_log_level(my_checker) = failure);

        checker_init;
        check_warnings(false);
        checker_init(default_level => failure);
        check_warnings(false);
        assert_true(get_default_log_level(default_checker) = failure);
      elsif run("Test changing checker name") then
        mock_core_failure;

        checker_init(my_checker);
        check_warnings(true);
        checker_init(my_checker, default_src => "my_checker");
        check_log(default_logger, deprecated_checker_init_msg,  warning);
        check_core_failure("Changing checker name is not supported");

        checker_init;
        check_warnings(false);
        checker_init(default_src => "my_checker");
        check_log(default_logger, deprecated_checker_init_msg,  warning);
        check_core_failure("Changing checker name is not supported");

        unmock_core_failure;
      elsif run("Test enabling and disabling of pass messages for custom checker") then
        my_checker := new_checker("my_checker");
        my_checker_logger := get_logger(my_checker);

        check(get_log_level(my_checker_logger, display_handler) = info);
        check(get_log_level(my_checker_logger, file_handler) = debug);
        enable_pass_msg(my_checker, display_handler);
        check(get_log_level(my_checker_logger, display_handler) = pass);
        check(get_log_level(my_checker_logger, file_handler) = debug);
        disable_pass_msg(my_checker, display_handler);
        check(get_log_level(my_checker_logger, display_handler) = debug);
        check(get_log_level(my_checker_logger, file_handler) = debug);

        set_log_level(my_checker_logger, display_handler, log_level_t'leftof(pass));
        enable_pass_msg(my_checker, display_handler);
        check(get_log_level(my_checker_logger, display_handler) = log_level_t'leftof(pass));
        check(get_log_level(my_checker_logger, file_handler) = debug);
        set_log_level(my_checker_logger, display_handler, log_level_t'rightof(pass));
        disable_pass_msg(my_checker, display_handler);
        check(get_log_level(my_checker_logger, display_handler) = log_level_t'rightof(pass));
        check(get_log_level(my_checker_logger, file_handler) = debug);

        enable_pass_msg(my_checker);
        check(get_log_level(my_checker_logger, display_handler) = pass);
        check(get_log_level(my_checker_logger, file_handler) = pass);
        disable_pass_msg(my_checker);
        check(get_log_level(my_checker_logger, display_handler) = debug);
        check(get_log_level(my_checker_logger, file_handler) = debug);

        set_log_level(my_checker_logger, display_handler, log_level_t'leftof(pass));
        set_log_level(my_checker_logger, file_handler, log_level_t'leftof(pass));
        enable_pass_msg(my_checker);
        check(get_log_level(my_checker_logger, display_handler) = log_level_t'leftof(pass));
        check(get_log_level(my_checker_logger, file_handler) = log_level_t'leftof(pass));
        set_log_level(my_checker_logger, display_handler, log_level_t'rightof(pass));
        set_log_level(my_checker_logger, file_handler, log_level_t'rightof(pass));
        disable_pass_msg(my_checker);
        check(get_log_level(my_checker_logger, display_handler) = log_level_t'rightof(pass));
        check(get_log_level(my_checker_logger, file_handler) = log_level_t'rightof(pass));

      elsif run("Test enabling and disabling of pass messages for default checker") then
        check(get_log_level(check_logger, display_handler) = info);
        check(get_log_level(check_logger, file_handler) = debug);
        enable_pass_msg(display_handler);
        check(get_log_level(check_logger, display_handler) = pass);
        check(get_log_level(check_logger, file_handler) = debug);
        disable_pass_msg(display_handler);
        check(get_log_level(check_logger, display_handler) = debug);
        check(get_log_level(check_logger, file_handler) = debug);

        set_log_level(check_logger, display_handler, log_level_t'leftof(pass));
        enable_pass_msg(display_handler);
        check(get_log_level(check_logger, display_handler) = log_level_t'leftof(pass));
        check(get_log_level(check_logger, file_handler) = debug);
        set_log_level(check_logger, display_handler, log_level_t'rightof(pass));
        disable_pass_msg(display_handler);
        check(get_log_level(check_logger, display_handler) = log_level_t'rightof(pass));
        check(get_log_level(check_logger, file_handler) = debug);

        enable_pass_msg;
        check(get_log_level(check_logger, display_handler) = pass);
        check(get_log_level(check_logger, file_handler) = pass);
        disable_pass_msg;
        check(get_log_level(check_logger, display_handler) = debug);
        check(get_log_level(check_logger, file_handler) = debug);

        set_log_level(check_logger, display_handler, log_level_t'leftof(pass));
        set_log_level(check_logger, file_handler, log_level_t'leftof(pass));
        enable_pass_msg;
        check(get_log_level(check_logger, display_handler) = log_level_t'leftof(pass));
        check(get_log_level(check_logger, file_handler) = log_level_t'leftof(pass));
        set_log_level(check_logger, display_handler, log_level_t'rightof(pass));
        set_log_level(check_logger, file_handler, log_level_t'rightof(pass));
        disable_pass_msg;
        check(get_log_level(check_logger, display_handler) = log_level_t'rightof(pass));
        check(get_log_level(check_logger, file_handler) = log_level_t'rightof(pass));
      elsif run("Test found errors subprograms") then
        my_checker := new_checker("my_checker");

        reset_checker_stat(my_checker);
        reset_checker_stat;

        assert_false(checker_found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        checker_found_errors(found_errors);
        assert_false(found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        checker_found_errors(my_checker, found_errors);
        assert_false(found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        check_failed(level => warning);
        assert_true(checker_found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        checker_found_errors(found_errors);
        assert_true(found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        reset_checker_stat;

        check_failed(my_checker, level => warning);
        checker_found_errors(my_checker, found_errors);
        assert_true(found_errors);
        check_only_log(default_logger, "Using deprecated checker_found_errors. Use get_checker_stat instead.", warning);

        reset_checker_stat(my_checker);

      end if;

      unmock(default_logger);
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
