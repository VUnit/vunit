-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_same_sim_all_pass_nonzero is
  generic (
    output_path : string;
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_same_sim_all_pass_nonzero is
begin
  test_runner : process
    variable counter : integer := 1;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test 1") then
        wait for 10 ns;
        report "Test 1";
        assert counter = 1;
        counter := counter + 1;
      elsif run("Test 2") then
        wait for 10 ns;
        report "Test 2";
        assert counter = 2;
        counter := counter + 1;
      end if;
    end loop;
    vunit_lib.runner_pkg.p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    assert false severity error;
    wait;
  end process;
end architecture;
