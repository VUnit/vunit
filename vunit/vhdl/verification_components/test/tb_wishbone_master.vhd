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

  constant bus_handle : bus_master_t := new_bus(data_length => dat_width,
      address_length => adr_width);
	constant ack_actor 		: actor_t := new_actor("ack_actor");
  constant tb_logger : logger_t := get_logger("tb");
  constant slave_logger : logger_t := get_logger("slave");
  signal slave_index : natural := 0;

  constant num_block_cycles : natural := 4;
begin

  main_stim : process
    variable tmp : std_logic_vector(dat_i'range);
    variable bus_rd_ref1 : bus_reference_t;
    variable bus_rd_ref2 : bus_reference_t;
    type bus_reference_arr_t is array (0 to num_block_cycles-1) of bus_reference_t;
    variable rd_ref : bus_reference_arr_t;
  begin
    test_runner_setup(runner, runner_cfg);
	  wait until rising_edge(clk);
    if run("Test block write") then
      verbose(tb_logger, "Test block write");
      for i in 0 to num_block_cycles-1 loop
        write_bus(net, bus_handle, i,
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;

    elsif run("Test block read") then
      verbose(tb_logger, "Test block read");
      for i in 0 to num_block_cycles-1 loop
        read_bus(net, bus_handle, i, rd_ref(i));
      end loop;
      verbose(tb_logger, "Get data by its references");
      for i in 0 to num_block_cycles-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;
    end if;

    wait until rising_edge(clk) and slave_index >= num_block_cycles-1;
    wait for 100 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);
  set_format(display_handler, verbose, true);
  show(slave_logger, display_handler, verbose);
  show(tb_logger, display_handler, verbose);
  show(default_logger, display_handler, verbose);

  slave : process
    variable wr_request_msg : msg_t;
    variable rd_request_msg : msg_t;
  begin
    wait until (cyc and stb) = '1' and rising_edge(clk);
    if we = '1' then
      verbose(slave_logger, "Write cycle start");
      check_equal(adr, std_logic_vector(to_unsigned(slave_index, adr'length)), "adr");
      check_equal(dat_o, std_logic_vector(to_unsigned(slave_index, dat_o'length)), "dat_o");
      wr_request_msg := new_msg(bus_write_msg);
      send(net, ack_actor, wr_request_msg);
      slave_index <= slave_index +1;
    elsif we = '0' then
      verbose(slave_logger, "Read cycle start");
      check_equal(adr, std_logic_vector(to_unsigned(slave_index, adr'length)), "adr");
      rd_request_msg := new_msg(bus_read_msg);
      push_std_ulogic_vector(rd_request_msg,
              std_logic_vector(to_unsigned(slave_index, dat_o'length)));
      send(net, ack_actor, rd_request_msg);
      slave_index <= slave_index +1;
    end if;
  end process;

  slave_ack : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable data : std_logic_vector(dat_i'range);
  begin
    verbose(slave_logger, "Slave ack: blocking on receive");
    receive(net, ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = bus_write_msg then
      verbose(slave_logger, "Start ack write");
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';
      verbose(slave_logger, "Write cycle passed");

    elsif msg_type = bus_read_msg then
      verbose(slave_logger, "Start ack read");
      data := pop_std_ulogic_vector(request_msg);
      dat_i <= data;
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';
      verbose(slave_logger, "Read cycle passed");

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

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

  clk <= not clk after 5 ns;

end architecture;
