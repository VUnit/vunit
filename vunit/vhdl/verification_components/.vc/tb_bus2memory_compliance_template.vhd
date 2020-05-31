-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vunit_context;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use vunit_lib.bus2memory_pkg.all;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_bus2memory_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_bus2memory_compliance is
  constant bus2memory_handle : bus2memory_t := new_bus2memory(
    data_length => 8,
    address_length => 8,
    memory => new_memory
  );
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.bus2memory
    generic map(bus2memory_handle);

end architecture;
