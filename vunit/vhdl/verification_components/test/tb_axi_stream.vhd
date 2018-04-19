-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.axi_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

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
    variable last : boolean;
    variable reference_queue : queue_t := new_queue;
    variable reference : stream_reference_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test single push and pop") then
      push_stream(net, master_stream, x"77");
      pop_stream(net, slave_stream, data);
      check_equal(data, std_logic_vector'(x"77"), "pop stream data");

    elsif run("test single push and pop with tlast") then
      push_stream(net, master_stream, x"88", true);
      pop_stream(net, slave_stream, data, last);
      check_equal(data, std_logic_vector'(x"88"), "pop stream data");
      check_equal(last, true, "pop stream last");

    elsif run("test single axi push and pop") then
      push_axi_stream(net, master_axi_stream, x"99", tlast => '1');
      pop_stream(net, slave_stream, data, last);
      check_equal(data, std_logic_vector'(x"99"), "pop stream data");
      check_equal(last, true, "pop stream last");

    elsif run("test pop before push") then
      for i in 0 to 7 loop
        pop_stream(net, slave_stream, reference);
        push(reference_queue, reference);
      end loop;

      for i in 0 to 7 loop
        push_stream(net, master_stream,
                    std_logic_vector(to_unsigned(i+1, data'length)));
      end loop;

      for i in 0 to 7 loop
        reference := pop(reference_queue);
        await_pop_stream_reply(net, reference, data);
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
