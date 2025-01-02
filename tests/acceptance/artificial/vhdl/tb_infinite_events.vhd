-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_infinite_events is
  generic (runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_infinite_events is
 signal toggle : boolean := false;
begin
  -- Trigger infinite simulation events
  -- to prove that simulation still ends at test_runner_cleanup
  -- When not events the simulation will finish anyway
  toggle <= not toggle after 1 ns;

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    wait for 10 ns;
    test_runner_cleanup(runner);
    wait;
  end process;

end architecture;
