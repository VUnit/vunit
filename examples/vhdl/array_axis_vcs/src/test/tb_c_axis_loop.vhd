-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

-- This testbench is a Minimum Working Example (MWE) of VUnit's resources to read/write data from a buffer
-- allocated in a foreign C application, and to verify AXI4-Stream components. Data is sent to an AXI4-Stream
-- Slave. The AXI4-Stream Slave is expected to be connected to an AXI4-Stream Master either directly or
-- (preferredly) through a FIFO, thus composing a loopback. Therefore, as data is pushed to the AXI4-Stream
-- Slave interface, the output is read from the AXI4-Stream Master interface and it is saved back to the buffer
-- shared with the software application.

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

use work.pkg_c;
use work.pkg_c.all;

entity tb_c_axis_loop is
  generic (
    runner_cfg : string;
    tb_path    : string
  );
end entity;

architecture tb of tb_c_axis_loop is
  -- Simulation constants

  constant clk_period    : time    := 20 ns;
  constant stream_length : integer := get_param(0);
  constant data_width    : natural := get_param(1);
  constant fifo_depth    : natural := get_param(2);

  -- AXI4Stream Verification Components

  constant m_axis : axi_stream_master_t := new_axi_stream_master(data_length => data_width);
  constant s_axis : axi_stream_slave_t := new_axi_stream_slave(data_length => data_width);

  constant ibuffer: pkg_c.memory_t := pkg_c.new_memory(0);
  constant obuffer: pkg_c.memory_t := pkg_c.new_memory(1);

  -- tb signals and variables

  signal clk, rst, rstn     : std_logic := '0';
  signal start, sent, saved : boolean   := false;

begin

  clk <= not clk after (clk_period/2);
  rstn <= not rst;

  main: process
    procedure run_test is begin
      info("Init test");
      wait until rising_edge(clk); start <= true;
      wait until rising_edge(clk); start <= false;
      wait until (sent and saved and rising_edge(clk));
      info("Test done");
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        rst <= '1';
        wait for 15*clk_period;
        rst <= '0';
        run_test;
        end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

--

  stimuli: process
    variable last : std_logic;
  begin
    sent <= false;
    wait until start and rising_edge(clk);

    for y in 0 to stream_length-1 loop
      wait until rising_edge(clk);
      push_axi_stream(net, m_axis, pkg_c.read_word(ibuffer, 4*y, 4) , tlast => '0');
    end loop;

    info("m_I sent!");

    wait until rising_edge(clk);
    sent <= true;
    wait;
  end process;

  save: process
    variable o : std_logic_vector(31 downto 0);
    variable last : std_logic:='0';
  begin
    saved <= false;
    wait until start and rising_edge(clk);
    wait for 50*clk_period;

    for y in 0 to stream_length-1 loop
      pop_axi_stream(net, s_axis, tdata => o, tlast => last);
      pkg_c.write_word(obuffer, 4*y, o);
    end loop;

    info("m_O read!");

    wait until rising_edge(clk);
    saved <= true;
    wait;
  end process;

--

  uut_vc: entity work.tb_vc_axis_loop
    generic map (
      m_axis => m_axis,
      s_axis => s_axis,
      data_width => data_width,
      fifo_depth => fifo_depth
    )
    port map (
      clk  => clk,
      rstn => rstn
    );

end architecture;
