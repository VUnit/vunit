-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- start_snippet tb_run_all_in_same_sim
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_run_all_in_same_sim is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_run_all_in_same_sim is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- vunit: run_all_in_same_sim
    while test_suite loop
      if run("Test to_string for integer again") then
        check_equal(to_string(17), "17");
      elsif run("Test to_string for boolean again") then
        check_equal(to_string(true), "true");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
-- end_snippet tb_run_all_in_same_sim

