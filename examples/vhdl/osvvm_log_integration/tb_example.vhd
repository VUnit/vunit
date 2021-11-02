-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.AlertLogPkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity tb_example is
  generic (
    runner_cfg : string;
    use_osvvm_log : boolean;
    use_vunit_log : boolean);
end entity;

architecture tb of tb_example is

begin
  main : process
    constant logger : logger_t := get_logger("A VUnit logger name");
    constant parent_logger : logger_t := get_logger("VUnit parent");
    constant child_logger : logger_t := get_logger("VUnit child", parent_logger);
    constant checker : checker_t := new_checker(logger);

    constant id : AlertLogIDType := GetAlertLogID("An OSVVM ID");
    constant parent_id : AlertLogIDType := GetAlertLogID("OSVVM parent");
    constant child_id : AlertLogIDType := GetAlertLogID("OSVVM child", parent_id);
  begin
    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    if use_osvvm_log then
      print(LF & "-------------------------------------------------------------------");
      print("This is what VUnit log messages look like when piped through OSVVM:");
      print("-------------------------------------------------------------------" & LF);
    else
      print(LF & "------------------------------------------------------------------------");
      print("This is what standard VUnit log messages look like. Call run.py");
      print("with --use-osvvm-log to see what is looks like when piped through OSVVM.");
      print("------------------------------------------------------------------------" & LF);
    end if;

    info(logger, "Hello from VUnit");
    check(checker, false, "An error from VUnit");
    info(child_logger, "Hello from VUnit hierarchy");

    if use_vunit_log then
      print(LF & "-------------------------------------------------------------------");
      print("This is what OSVVM log messages look like when piped through VUnit:");
      print("-------------------------------------------------------------------" & LF);
    else
      print(LF & "------------------------------------------------------------------------");
      print("This is what standard OSVVM log messages look like. Call run.py");
      print("with --use-vunit-log to see what is looks like when piped through VUnit.");
      print("------------------------------------------------------------------------" & LF);
    end if;

    osvvm.AlertLogPkg.Log(id, "Hello from OSVVM");
    Alert(id, "An error from OSVVM");
    osvvm.AlertLogPkg.Log(child_id, "Hello from OSVVM hierarchy");

    if use_osvvm_log then
      print(LF & "------------------------------------------------------------------------");
      print("Only log messages are piped through OSVVM. Print messages outside of the");
      print("the logging framework are unaffected. For example this FAILURE");
      print("message.");
      print("------------------------------------------------------------------------" & LF);
    else
      print(LF & "");
    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1000 ns);


end architecture;
