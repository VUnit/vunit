-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

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

begin

  main : process
    variable tmp : std_logic_vector(dat_i'range);
  begin
    test_runner_setup(runner, runner_cfg);
	wait until rising_edge(clk);
    if run("Test single write") then
      write_bus(net, bus_handle, x"e", x"abcd");
    elsif run("Test single read") then
      info("Start read test");
      read_bus(net, bus_handle, x"e", tmp);
      info("Check equal");
      check_equal(tmp, std_logic_vector'(x"5566"), "read data");
    elsif run("Test block write") then
      verbose(tb_logger, "Test block write`");
      write_bus(net, bus_handle, x"e", x"abcd");
      verbose(tb_logger, "Wrote first");
      write_bus(net, bus_handle, x"e", x"abcd");
      verbose(tb_logger, "Wrote second");
    end if;

    wait for 200 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);
  set_format(display_handler, verbose, true);
  show(slave_logger, display_handler, verbose);
  show(tb_logger, display_handler, verbose);
  show(default_logger, display_handler, verbose);
  -- Show log messages from the logger of the specified log_levels to this handler
--  procedure show(logger : logger_t;
--                 log_handler : log_handler_t;
--                 log_levels : log_level_vec_t;
--                 include_children : boolean := true);

  slave : process
    variable wr_request_msg : msg_t;
    variable rd_request_msg : msg_t := new_msg(bus_read_msg);
  begin
    wait for 1 ns;
    if enabled("Test single write") then
      info("Wait on write cycle start");
      wait until (cyc and stb and we) = '1' and rising_edge(clk);
      check_equal(adr, std_logic_vector'(x"e"), "adr");
      send(net, ack_actor, wr_request_msg);

    elsif enabled("Test single read") then
      info("Wait on read cycle start");
      wait until (cyc and stb) = '1' and we = '0' and rising_edge(clk);
      check_equal(adr, std_logic_vector'(x"e"), "adr");
      send(net, ack_actor, rd_request_msg);

    elsif enabled("Test block write") then
      verbose(slave_logger, "Wait on write cycle start");
      wait until (cyc and stb and we) = '1' and rising_edge(clk);
      check_equal(adr, std_logic_vector'(x"e"), "adr");
      wr_request_msg := new_msg(bus_write_msg);
      push_std_ulogic_vector(wr_request_msg, x"abcd");
      send(net, ack_actor, wr_request_msg);
    end if;
  end process;

  slave_ack : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    verbose(slave_logger, "Support ack: blocking on receive");
    receive(net, ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = bus_write_msg then
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';
      check_equal(dat_o, std_logic_vector'(x"abcd"), "dat_o");
      verbose(slave_logger, "Write cycle passed");

    elsif msg_type = bus_read_msg then
      dat_i <= x"5566";
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
