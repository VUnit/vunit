-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity other_file_tests is
  generic (
    nested_runner_cfg : runner_cfg_t);
end entity;

architecture vunit_test_bench of other_file_tests is
begin
  test_runner : process
  begin
    test_runner_setup(runner, nested_runner_cfg);
    while test_suite loop
      if run("pass") then
        report "Test pass";
      elsif run("fail") then
        report "Test fail";
        assert false;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
