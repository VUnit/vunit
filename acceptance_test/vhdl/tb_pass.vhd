-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

entity tb_pass is
end entity;

architecture vunit_test_bench of tb_pass is
 signal vunit_finished : boolean := false;
begin
  test_runner : process
  begin
    vunit_finished <= true;
    wait;
  end process;
end architecture;
