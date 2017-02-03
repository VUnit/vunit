-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_assert_stop_level is
  generic (runner_cfg : string;
           level : string);
end entity;

architecture vunit_test_bench of tb_assert_stop_level is
begin
  test_runner : process
    procedure make_report(constant level : in string) is
    begin
      report level severity severity_level'value(level);
    end procedure make_report;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test with VHDL assert stop level = warning") then
        make_report(level);
      elsif run("Test with VHDL assert stop level = error") then
        make_report(level);
      elsif run("Test with VHDL assert stop level = failure") then
        make_report(level);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
-- This pragma should be ignored when VHDL assert stop level is used
-- vunit_pragma fail_on_warning
