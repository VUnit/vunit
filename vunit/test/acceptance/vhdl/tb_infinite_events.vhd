-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

entity tb_infinite_events is
end entity;

architecture vunit_test_bench of tb_infinite_events is
 signal vunit_finished : boolean := false;
 signal toggle : boolean := false;
begin
  -- Trigger infinite simulation events
  -- to prove that simulation still ends at vunit_finished
  -- When not events the simulation will finish anway
  toggle <= not toggle after 1 ns;

  test_runner : process
  begin
    wait for 10 ns;
    vunit_finished <= true;
    wait;
  end process;

end architecture;
