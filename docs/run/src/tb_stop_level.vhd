-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_stop_level is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_stop_level is
begin
  -- start_snippet tb_stop_level
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("Test that fails multiple times but doesn't stop") then
        check_equal(17, 18);
        check_equal(17, 19);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
  -- end_snippet tb_stop_level
end;
