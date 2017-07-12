-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.axi_stream_pkg.all;
use work.stream_pkg.all;
use work.logger_pkg.all;

entity tb_axi_stream is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_stream is
  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(data_length => 8);
  constant master_stream : stream_master_t := as_stream(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave(data_length => 8);
  constant slave_stream : stream_slave_t := as_stream(slave_axi_stream);

  signal aclk   : std_logic := '0';
  signal tvalid : std_logic;
  signal tready : std_logic;
  signal tdata  : std_logic_vector(data_length(slave_axi_stream)-1 downto 0);
  signal tlast : std_logic;
begin

  main : process
    variable data : std_logic_vector(tdata'range);
    variable reference_queue : queue_t := allocate;
    variable reference : stream_reference_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test single write and read") then
      write_stream(event, master_stream, x"77");
      read_stream(event, slave_stream, data);
      check_equal(data, std_logic_vector'(x"77"), "read stream data");

    elsif run("test single axi write and read") then
      write_axi_stream(event, master_axi_stream, x"88", tlast => '1');
      read_stream(event, slave_stream, data);
      check_equal(data, std_logic_vector'(x"88"), "read stream data");

    elsif run("test stream read expects tlast") then
      mock(axi_stream_logger);
      write_axi_stream(event, master_axi_stream, x"99", tlast => '0');
      read_stream(event, slave_stream, data);
      check_only_log(axi_stream_logger,
                     "Expected tlast = '1' in single transaction write got 0",
                     failure);
      unmock(axi_stream_logger);

    elsif run("test read before write") then
      for i in 0 to 7 loop
        read_stream(event, slave_stream, reference);
        push(reference_queue, reference);
      end loop;

      for i in 0 to 7 loop
        write_stream(event, master_stream,
                     std_logic_vector(to_unsigned(i+1, data'length)));
      end loop;

      for i in 0 to 7 loop
        reference := pop(reference_queue);
        await_read_stream_reply(event, reference, data);
        check_equal(data, to_unsigned(i+1, data'length));
      end loop;
    end if;
    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 10 ms);

  axi_stream_master_inst : entity work.axi_stream_master
    generic map (
      master => master_axi_stream)
    port map (
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast);

  axi_stream_slave_inst : entity work.axi_stream_slave
    generic map (
      slave => slave_axi_stream)
    port map (
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast);

  aclk <= not aclk after 5 ns;
end architecture;
