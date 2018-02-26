-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Slawomir Siluk slaweksiluk@gazeta.pl 2018
-- TODO:
-- - stall
-- - generic num_block_cycles
-- - generic ack delay
-- - random ack 0/1
-- - fix slave_index when reading

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

use work.axi_pkg.all;
use work.bus_master_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_wishbone_master is
  generic (runner_cfg : string);
end entity;

architecture a of tb_wishbone_master is
  constant dat_width    : positive := 16;
  constant adr_width    : positive := 4;

  signal clk    : std_logic := '0';
  signal adr    : std_logic_vector(adr_width-1 downto 0);
  signal dat_i  : std_logic_vector(dat_width-1 downto 0);
  signal dat_o  : std_logic_vector(dat_width-1 downto 0);
  signal sel   : std_logic_vector(dat_width/8 -1 downto 0);
  signal cyc   : std_logic := '0';
  signal stb   : std_logic := '0';
  signal we    : std_logic := '0';
  signal ack   : std_logic := '0';

  constant master_logger : logger_t := get_logger("master");
  constant tb_logger : logger_t := get_logger("tb");
  constant bus_handle : bus_master_t := new_bus(data_length => dat_width,
      address_length => adr_width, logger => master_logger);

  constant num_block_cycles : natural := 4;
begin

  main_stim : process
    variable tmp : std_logic_vector(dat_i'range);
    variable value : std_logic_vector(dat_i'range) := x"abcd";
    variable bus_rd_ref1 : bus_reference_t;
    variable bus_rd_ref2 : bus_reference_t;
    type bus_reference_arr_t is array (0 to num_block_cycles-1) of bus_reference_t;
    variable rd_ref : bus_reference_arr_t;
  begin
    test_runner_setup(runner, runner_cfg);
	  wait until rising_edge(clk);

    if run("Test single write, read") then
      trace(tb_logger, "RW single test");    
      write_bus(net, bus_handle, 0, value);
      
      wait for 50 ns;
      read_bus(net, bus_handle, 0, tmp);
      check_equal(tmp, value, "read data");
	  
    elsif run("Test block write") then
      trace(tb_logger, "Test block write");
      for i in 0 to num_block_cycles-1 loop
        write_bus(net, bus_handle, i,
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;

    elsif run("Test block read") then
      trace(tb_logger, "Test block read");
      for i in 0 to num_block_cycles-1 loop
        read_bus(net, bus_handle, i, rd_ref(i));
      end loop;
      trace(tb_logger, "Get data by its references");
      for i in 0 to num_block_cycles-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;
    end if;

    wait for 1000 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);
  set_format(display_handler, verbose, true);
  show(tb_logger, display_handler, verbose);
  show(default_logger, display_handler, verbose);
  show(master_logger, display_handler, verbose);
  show(com_logger, display_handler, verbose);
  

  dut : entity work.wishbone_master
    generic map (
      bus_handle => bus_handle)
    port map (
      clk   => clk,
      adr   => adr,
      dat_i => dat_i,
      dat_o => dat_o,
      sel   => sel,
      cyc   => cyc,
      stb   => stb,
      we    => we,
      ack   => ack
    );
    
  dut_slave : entity work.wishbone_slave
    port map (
      clk   => clk,
      adr   => adr,
      dat_i => dat_o,
      dat_o => dat_i,
      sel   => sel,
      cyc   => cyc,
      stb   => stb,
      we    => we,
      ack   => ack
    );    

  clk <= not clk after 5 ns;

end architecture;
