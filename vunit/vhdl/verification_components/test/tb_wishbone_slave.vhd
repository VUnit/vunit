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

entity tb_wishbone_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_wishbone_slave is
  constant dat_width    : positive := 8;
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


  constant tb_logger : logger_t := get_logger("tb");

  constant num_block_cycles : natural := 3;
begin

  main_stim : process
    variable tmp : std_logic_vector(dat_i'range);
    variable value : std_logic_vector(dat_i'range) := x"ab";
  begin
    test_runner_setup(runner, runner_cfg);
	  wait until rising_edge(clk);

    if run("wr single rd single") then
      write_bus(net, bus_handle, 0, value);
      
      wait until ack = '1' and rising_edge(clk);
      wait until rising_edge(clk);
      read_bus(net, bus_handle, 0, tmp);
      check_equal(tmp, value, "read data");
      
--    elsif run("wr block") then
--      -- TODO not sure if is allowed to toggle signal we during
--      -- wishbone single cycle
--      write_bus(net, bus_handle, 0, value);
--      read_bus(net, bus_handle, 0, tmp);
--      check_equal(tmp, value, "read data");
      
    elsif run("wr block rd single") then
      info(tb_logger, "Writing...");
      for i in 0 to num_block_cycles-1 loop
        write_bus(net, bus_handle, i,
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;
      
      for i in 1 to num_block_cycles loop
        wait until ack = '1' and rising_edge(clk);
      end loop;
      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      for i in 0 to num_block_cycles-1 loop
        read_bus(net, bus_handle, i, tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;

    elsif run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to num_block_cycles-1 loop
        write_bus(net, bus_handle, i,
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;
      
      info(tb_logger, "Sleeping...");
      for i in 1 to num_block_cycles loop
        wait until ack = '1' and rising_edge(clk);
      end loop;
      wait for 100 ns;
      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      for i in 0 to num_block_cycles-1 loop
        read_bus(net, bus_handle, i, rd_ref(i));
      end loop;

      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 100 ns;
	
      trace(tb_logger, "Get reads by references...");
      for i in 0 to num_block_cycles-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        --check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;
	  -- With references
--    elsif run("WR block") then
--      for i in 0 to num_block_cycles-1 loop
--        write_bus(net, bus_handle, i,
--            std_logic_vector(to_unsigned(i, dat_i'length)));
--      end loop;

--      trace(tb_logger, "Test block read");
--      for i in 0 to num_block_cycles-1 loop
--        read_bus(net, bus_handle, i, rd_ref(i));
--      end loop;
--      trace(tb_logger, "Get data by its references");
--      for i in 0 to num_block_cycles-1 loop
--        await_read_bus_reply(net, rd_ref(i), tmp);
--        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
--      end loop;
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
