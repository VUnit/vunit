-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use vunit_lib.signal_driver_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_std_logic_driver_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_std_logic_driver_compliance is

  constant signal_driver : signal_driver_t := new_signal_driver(
    initial => std_logic_vector'(x"1A2B")
  );

  signal clk : std_logic;
  signal value : std_logic_vector(15 downto 0);

begin
  -- DO NOT modify the test runner process.
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  -- DO NOT modify the VC instantiation.
  vc_inst: entity vunit_lib.std_logic_driver
    generic map(signal_driver)
    port map(
      clk => clk,
      value => value
    );

end architecture;
