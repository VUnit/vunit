-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- This test bench is to reproduce issue with pop form empty queue in modelsim.
library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

entity tb_avalon is
    generic (runner_cfg : string);
end tb_avalon;

architecture testbench of tb_avalon is

    -- Avalon-MM Slave --
    signal av_address : std_logic_vector(31 downto 0);
    signal av_write : std_logic := '0';
    signal av_writedata : std_logic_vector(31 downto 0) := (others=> '0');
    signal av_read : std_logic := '0';
    signal av_readdata : std_logic_vector(31 downto 0) := (others=> '0');
    signal av_byteenable : std_logic_vector(3 downto 0);
    signal av_burstcount : std_logic_vector(3 downto 0);

    constant avalon_bus : bus_master_t := new_bus(data_length => 32, address_length => av_address'length);

    signal clk : std_logic := '0';

    constant CLK_period : time := 20 ns;

begin

    avalon_master : entity vunit_lib.avalon_master
    generic map (
      bus_handle => avalon_bus,
      use_readdatavalid => false,
      fixed_read_latency => 0
    )
    port map (
      clk => clk,
      address => av_address,
      byteenable => av_byteenable,
      burstcount => av_burstcount,
      write => av_write,
      writedata => av_writedata,
      read => av_read,
      readdata => av_readdata,
      readdatavalid => '0',
      waitrequest => '0'
    );

    clk <= not clk after CLK_period/2;

    tests: process
    begin
      test_runner_setup(runner, runner_cfg);
      wait for CLK_period*2;
      check_bus(net, avalon_bus, 0, (0 to 31 => '0'));
      test_runner_cleanup(runner);
    end process;

end;
