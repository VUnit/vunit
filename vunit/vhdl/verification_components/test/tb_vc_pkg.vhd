-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;
use work.vc_pkg.all;

entity tb_vc_pkg is
  generic(runner_cfg : string);
end entity;

architecture a of tb_vc_pkg is
begin

  main : process
    variable std_cfg : std_cfg_t;
    constant default_logger1 : logger_t := get_logger("default_logger1");
    constant default_checker1 : checker_t := new_checker(get_logger("default_checker1"));
    constant default_checker_based_on_default_checker1 : checker_t := new_checker(default_logger1);
    constant default_logger2 : logger_t := get_logger("default_logger2");
    constant default_checker2 : checker_t := new_checker(get_logger("default_checker2"));
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that no warnings are issued for first std cfg using the default logger") then
        mock(default_logger1, warning);
        std_cfg := create_std_cfg(default_logger1, default_checker1);
        std_cfg := create_std_cfg(default_logger2, default_checker2);
        check_no_log;
        unmock(default_logger1);

      elsif run("Test that no warnings are issued for when a std cfg use the default logger for the default checker") then
        mock(default_logger1, warning);
        std_cfg := create_std_cfg(default_logger1, default_checker_based_on_default_checker1);
        check_no_log;
        unmock(default_logger1);

      elsif run("Test that no warnings are issued for when the input logger to std cfg reuse the default logger") then
        mock(default_logger1, warning);
        std_cfg := create_std_cfg(default_logger1, default_checker1);
        std_cfg := create_std_cfg(default_logger2, default_checker2, logger => default_logger1);
        check_no_log;
        unmock(default_logger1);

      elsif run("Test that a warning is issued when a std cfg is created with an already used default logger") then
        mock(default_logger1, warning);
        std_cfg := create_std_cfg(default_logger1, default_checker1);
        std_cfg := create_std_cfg(default_logger1, default_checker2);
        check_only_log(default_logger1, "This logger is already used by another VC. Source VC for log messages is ambiguous.", warning);
        unmock(default_logger1);

      elsif run("Test that a warning is issued when a std cfg is created with a default checker using an already used default logger") then
        mock(default_logger1, warning);
        std_cfg := create_std_cfg(default_logger1, default_checker1);
        std_cfg := create_std_cfg(default_logger2, default_checker_based_on_default_checker1);
        check_only_log(default_logger1, "This logger is already used by another VC. Source VC for log messages is ambiguous.", warning);
        unmock(default_logger1);

      elsif run("Test that a warning is issued when a std cfg is created with a default checker using an logger already used by a default checker") then
        mock(get_logger(default_checker1), warning);
        std_cfg := create_std_cfg(default_logger1, default_checker1);
        std_cfg := create_std_cfg(default_logger2, default_checker1);
        check_only_log(get_logger(default_checker1), "This logger is already used by another VC. Source VC for log messages is ambiguous.", warning);
        unmock(get_logger(default_checker1));

      end if;
    end loop;
    test_runner_cleanup(runner, fail_on_warning => true);
  end process;
end architecture;
