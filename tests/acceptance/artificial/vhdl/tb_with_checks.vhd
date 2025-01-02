-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_checks is
  generic (
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_with_checks is
begin
  test_runner : process
    variable pass : boolean;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test passing check") then
        wait for 10 ns;
        check(true, "Should pass");
      elsif run("Test failing check") then
        wait for 10 ns;
        check(false, "Should pass");
      elsif run("Test non-stopping failing check") then
        wait for 10 ns;
        set_stop_level(failure);
        check(false, "Should fail");
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
