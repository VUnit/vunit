-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
use work.memory_pkg.all;
use work.bus_master_pkg.all;
use work.apb_slave_pkg.all;
use work.apb_master_pkg.all;
use work.logger_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_apb_master is
  generic (
    runner_cfg : string
  );
end entity;

architecture a of tb_apb_master is

  constant BUS_DATA_WIDTH    : natural := 16;
  constant BUS_ADDRESS_WIDTH : natural := 32;

  signal clk     : std_logic := '0';
  signal reset   : std_logic := '0';
  signal psel    : std_logic;
  signal penable : std_logic;
  signal paddr   : std_logic_vector(BUS_ADDRESS_WIDTH-1 downto 0);
  signal pwrite  : std_logic;
  signal pwdata  : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal prdata  : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal pready  : std_logic := '0';

  constant bus_handle : apb_master_t := new_apb_master(data_length => pwdata'length,
                                                       address_length => paddr'length);
  constant memory : memory_t := new_memory;
  constant slave_handle : apb_slave_t := new_apb_slave(memory => memory,
                                                       logger => get_logger("apb slave"),
                                                       ready_high_probability => 0.5);

  signal start : boolean := false;
begin

  main_stim : process
    variable buf : buffer_t;
    variable data, data2 : std_logic_vector(prdata'range);
    variable bus_ref1, bus_ref2 : bus_reference_t;
  begin
    show(get_logger("apb slave"), display_handler, debug);

    test_runner_setup(runner, runner_cfg);
    start <= true;
    wait for 0 ns;

    if run("single_write") then
      buf := allocate(memory => memory, num_bytes => 2, permissions => write_only);
      mock(get_logger(bus_handle), debug);
      set_expected_word(memory, base_address(buf), x"1122");
      write_bus(net, bus_handle, base_address(buf), x"1122");
      wait_until_idle(net, bus_handle);
      check_only_log(get_logger(bus_handle), "Wrote 0x1122 to address 0x00000000", debug);
      unmock(get_logger(bus_handle));
      check_expected_was_written(memory);

    elsif run("single_read") then
      buf := allocate(memory => memory, num_bytes => 2, permissions => read_only);
      write_word(memory, base_address(buf), x"1234");
      read_bus(net, bus_handle, base_address(buf), data);
      check_equal(data, std_logic_vector'(x"1234"), "Check read data.");

    elsif run("consecutive_reads") then
      buf := allocate(memory => memory, num_bytes => 4, permissions => read_only);
      write_word(memory, base_address(buf), x"1234");
      write_word(memory, base_address(buf)+2, x"5678");
      read_bus(net, bus_handle, base_address(buf), bus_ref1);
      read_bus(net, bus_handle, base_address(buf)+2, bus_ref2);
      await_read_bus_reply(net, bus_ref1, data);
      check_equal(data, std_logic_vector'(x"1234"), "Check read data.");
      await_read_bus_reply(net, bus_ref2, data);
      check_equal(data, std_logic_vector'(x"5678"), "Check read data.");

    elsif run("consecutive_writes") then
      buf := allocate(memory => memory, num_bytes => 4, permissions => write_only);
      set_expected_word(memory, base_address(buf), x"1234");
      set_expected_word(memory, base_address(buf)+2, x"5678");
      write_bus(net, bus_handle, base_address(buf), x"1234");
      write_bus(net, bus_handle, base_address(buf)+2, x"5678");
      wait_until_idle(net, bus_handle);
      check_expected_was_written(memory);

    elsif run("many_reads") then
      for i in 1 to 100 loop
        buf := allocate(memory => memory, num_bytes => 2, permissions => read_only);
        data := std_logic_vector(to_unsigned(i, BUS_DATA_WIDTH));
        write_word(memory, base_address(buf), data);
        read_bus(net, bus_handle, base_address(buf), data2);
        check_equal(data2, data, "Check read data.");
      end loop;

    elsif run("many_writes") then
      for i in 1 to 100 loop
        buf := allocate(memory => memory, num_bytes => 2, permissions => write_only);
        data := std_logic_vector(to_unsigned(i, BUS_DATA_WIDTH));
        set_expected_word(memory, base_address(buf), data);
        write_bus(net, bus_handle, base_address(buf), data);
      end loop;
      wait_until_idle(net, bus_handle);
      check_expected_was_written(memory);

    elsif run("wait_between_writes") then
      buf := allocate(memory => memory, num_bytes => 4, permissions => write_only);
      set_expected_word(memory, base_address(buf), x"1234");
      set_expected_word(memory, base_address(buf)+2, x"5678");
      write_bus(net, bus_handle, base_address(buf), x"1234");
      wait_for_time(net, bus_handle, 500 ns);
      write_bus(net, bus_handle, base_address(buf)+2, x"5678");
      wait_until_idle(net, bus_handle);
      check_expected_was_written(memory);

    end if;

    wait for 100 ns;

    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);

  U_DUT_MASTER: entity work.apb_master
    generic map (
      bus_handle => bus_handle 
    )
    port map (
      clk         => clk,
      reset       => reset,
      psel_o      => psel,
      penable_o   => penable,
      paddr_o     => paddr,
      pwrite_o    => pwrite,
      pwdata_o    => pwdata,
      prdata_i    => prdata,
      pready_i    => pready
    );

  U_DUT_SLAVE: entity work.apb_slave
    generic map (
      bus_handle  => slave_handle 
    )
    port map (
      clk         => clk,
      reset       => reset,
      psel_i      => psel,
      penable_i   => penable,
      paddr_i     => paddr,
      pwrite_i    => pwrite,
      pwdata_i    => pwdata,
      prdata_o    => prdata,
      pready_o    => pready
    );

  clk <= not clk after 5 ns;
end architecture;
