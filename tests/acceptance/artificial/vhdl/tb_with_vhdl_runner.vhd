-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_vhdl_runner is
  generic (
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_with_vhdl_runner is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("pass") then
        wait for 10 ns;
        report "Test pass";
      elsif run("fail") then
        wait for 10 ns;
        report "Test fail";
        assert false;
      elsif run("Test with spaces") then
        wait for 10 ns;
        report "Test with spaces";
      elsif run("Test that timeouts") then
        wait for 100 ns;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 50 ns);
end architecture;
