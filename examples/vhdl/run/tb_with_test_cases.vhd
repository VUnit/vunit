-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_test_cases is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_with_test_cases is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Put test suite setup code here

    while test_suite loop

      -- Put common test case setup code here

      if run("Test to_string for integer") then
        check_equal(to_string(17), "17");
      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");
      end if;

      -- Put common test case cleanup code here

    end loop;

    -- Put test suite cleanup code here

    test_runner_cleanup(runner);
  end process;
end architecture;
