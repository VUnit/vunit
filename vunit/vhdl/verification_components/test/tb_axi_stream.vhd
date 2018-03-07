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
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_axi_stream is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_stream is
  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(data_length => 8, id_length => 8, dest_length => 8, user_length => 8);
  constant master_stream : stream_master_t := as_stream(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave(data_length => 8, id_length => 8, dest_length => 8, user_length => 8);
  constant slave_stream : stream_slave_t := as_stream(slave_axi_stream);

  signal aclk   : std_logic := '0';
  signal tvalid : std_logic;
  signal tready : std_logic;
  signal tdata  : std_logic_vector(data_length(slave_axi_stream)-1 downto 0);
  signal tlast : std_logic;
  signal tkeep : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tstrb : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tid : std_logic_vector(id_length(slave_axi_stream)-1 downto 0);
  signal tdest : std_logic_vector(dest_length(slave_axi_stream)-1 downto 0);
  signal tuser : std_logic_vector(user_length(slave_axi_stream)-1 downto 0);
begin

  main : process
    variable data : std_logic_vector(tdata'range);
    variable last_bool : boolean;
    variable last : std_logic;
    variable keep : std_logic_vector(tkeep'range);
    variable strb : std_logic_vector(tstrb'range);
    variable id : std_logic_vector(tid'range);
    variable dest : std_logic_vector(tdest'range);
    variable user : std_logic_vector(tuser'range);
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
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"88"), "pop stream data");
      check_equal(last_bool, true, "pop stream last");

    elsif run("test single axi push and pop") then
      push_axi_stream(net, master_axi_stream, x"99", tlast => '1');
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"99"), "pop stream data");
      check_equal(last_bool, true, "pop stream last");
      
    elsif run("test single axi push and axi pop") then
      push_axi_stream(net, master_axi_stream, x"99", tlast => '1', tkeep => "1", tstrb => "1", tid => x"11", tdest => x"22", tuser => x"33" );
      pop_axi_stream(net, slave_axi_stream, data, last, keep, strb, id, dest, user );
      check_equal(data, std_logic_vector'(x"99"), "pop axi stream data");
      check_equal(last, std_logic'('1'), "pop stream last");  
      check_equal(keep, std_logic_vector'("1"), "pop stream keep");  
      check_equal(strb, std_logic_vector'("1"), "pop stream strb");  
      check_equal(id, std_logic_vector'(x"11"), "pop stream id");  
      check_equal(dest, std_logic_vector'(x"22"), "pop stream dest");  
      check_equal(user, std_logic_vector'(x"33"), "pop stream user");  

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
      tlast  => tlast,
      tkeep  => tkeep,
      tstrb  => tstrb,
      tid    => tid,
      tuser  => tuser,
      tdest  => tdest);

  axi_stream_slave_inst : entity work.axi_stream_slave
    generic map (
      slave => slave_axi_stream)
    port map (
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast,
      tkeep  => tkeep,
      tstrb  => tstrb,
      tid    => tid,
      tuser  => tuser,
      tdest  => tdest);

  aclk <= not aclk after 5 ns;
end architecture;
