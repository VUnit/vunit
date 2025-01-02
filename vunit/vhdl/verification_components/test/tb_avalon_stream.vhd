-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.avalon_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_avalon_stream is
  generic (runner_cfg : string);
end entity;

architecture a of tb_avalon_stream is
  constant avalon_source_stream : avalon_source_t :=
    new_avalon_source(data_length => 8, valid_high_probability => 0.1);
  constant master_stream : stream_master_t := as_stream(avalon_source_stream);

  constant avalon_sink_stream : avalon_sink_t :=
    new_avalon_sink(data_length => 8, ready_high_probability => 0.3);
  constant slave_stream : stream_slave_t := as_stream(avalon_sink_stream);

  signal clk   : std_logic := '0';
  signal valid : std_logic;
  signal ready : std_logic;
  signal sop   : std_logic;
  signal eop   : std_logic;
  signal data  : std_logic_vector(data_length(avalon_source_stream)-1 downto 0);
begin

  main : process
    variable tmp     : std_logic_vector(data'range);
    variable is_sop  : std_logic;
    variable is_eop  : std_logic;
    variable sop_tmp : std_logic;
    variable eop_tmp : std_logic;
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(avalon_sink_stream.p_logger, display_handler, trace);

    wait until rising_edge(clk);
    if run("test single push and pop") then
      push_stream(net, master_stream, x"77");
      pop_stream(net, slave_stream, tmp);
      check_equal(tmp, std_logic_vector'(x"77"), "pop stream data");

    elsif run("test double push and pop") then
      push_stream(net, master_stream, x"66");
      pop_stream(net, slave_stream, tmp);
      check_equal(tmp, std_logic_vector'(x"66"), "pop stream first data");

      push_stream(net, master_stream, x"55");
      pop_stream(net, slave_stream, tmp);
      check_equal(tmp, std_logic_vector'(x"55"), "pop stream second data");

    elsif run("push delay pop") then
      push_stream(net, master_stream, x"de");
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      pop_stream(net, slave_stream, tmp);
      check_equal(tmp, std_logic_vector'(x"de"), "pop stream data");

    elsif run("block push and pop") then
      for i in 0 to 7 loop
        push_stream(net, master_stream, std_logic_vector(to_unsigned(i, 8)));
        pop_stream(net, slave_stream, tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, 8)), "pop stream data"&natural'image(i));
      end loop;

    elsif run("test sop and eop") then
      for i in 0 to 7 loop
        if i = 0 then
          is_sop := '1';
          is_eop := '0';
        elsif i = 7 then
          is_sop := '0';
          is_eop := '1';
        else
          is_sop := '0';
          is_eop := '0';
        end if;
        push_avalon_stream(net, avalon_source_stream, std_logic_vector(to_unsigned(i, 8)), is_sop, is_eop);
        pop_avalon_stream(net, avalon_sink_stream, tmp, sop_tmp, eop_tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, 8)), "pop stream data"&natural'image(i));
        check_equal(sop_tmp, is_sop, "pop stream sop");
        check_equal(eop_tmp, is_eop, "pop stream eop");
      end loop;

    end if;
    wait until rising_edge(clk);
    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 10 ms);

  avalon_source_vc : entity work.avalon_source
    generic map (
      source => avalon_source_stream)
    port map (
      clk   => clk,
      valid => valid,
      ready => ready,
      sop   => sop,
      eop   => eop,
      data  => data
    );

  avalon_sink_vc : entity work.avalon_sink
    generic map (
      sink => avalon_sink_stream)
    port map (
      clk   => clk,
      valid => valid,
      ready => ready,
      sop   => sop,
      eop   => eop,
      data  => data
    );

  clk <= not clk after 5 ns;
end architecture;
