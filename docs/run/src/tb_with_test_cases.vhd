-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_test_cases is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_with_test_cases is
begin
  -- start_snippet test_runner_with_test_cases
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Put test suite setup code here. This code is common to the entire test suite
    -- and is executed *once* prior to all test cases.

    while test_suite loop

      -- Put test case setup code here. This code executed before *every* test case.

      if run("Test to_string for integer") then
        -- The test case code is placed in the corresponding (els)if branch.
        check_equal(to_string(17), "17");

      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");

      end if;

      -- Put test case cleanup code here. This code executed after *every* test case.

    end loop;

    -- Put test suite cleanup code here. This code is common to the entire test suite
    -- and is executed *once* after all test cases have been run.

    test_runner_cleanup(runner);
  end process;
  -- end_snippet test_runner_with_test_cases
end architecture;
