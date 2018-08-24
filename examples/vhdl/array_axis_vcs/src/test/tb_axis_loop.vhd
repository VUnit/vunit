-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

-- This testbench is a Minimum Working Example (MWE) of VUnit's resources to read/write CSV files and to verify
-- AXI4-Stream components. A CSV file that contains comma separated integers is read from `data_path & csv_i`, and it is
-- sent row by row to an AXI4-Stream Slave. The AXI4-Stream Slave is expected to be connected to an AXI4-Stream Master
-- either directly or (preferredly) through a FIFO, thus composing a loopback. Therefore, as data is pushed to the
-- AXI4-Stream Slave interface, the output is read from the AXI4-Stream Master interface and it is saved to
-- `data_path & csv_o`.

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
use vunit_lib.array_pkg.all;
use vunit_lib.axi_stream_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;

entity tb_axis_loop is
  generic (
    runner_cfg : string;
    tb_path    : string;
    csv_i      : string := "data/in.csv";
    csv_o      : string := "data/out.csv"
  );
end entity;

architecture tb of tb_axis_loop is

  -- Simulation constants

  constant clk_period : time := 20 ns;
  constant data_width : natural := 32;

  -- AXI4Stream Verification Components

  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(data_length => data_width);
  constant master_stream : stream_master_t := as_stream(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave(data_length => data_width);
  constant slave_stream : stream_slave_t := as_stream(slave_axi_stream);

  -- Signals to/from the UUT from/to the verification components

  signal m_valid, m_ready, m_last, s_valid, s_ready, s_last : std_logic;
  signal m_data, s_data : std_logic_vector(data_length(master_axi_stream)-1 downto 0);

  -- tb signals and variables

  signal clk, rst, rstn : std_logic := '0';
  shared variable m_I, m_O : array_t;
  signal start, done, saved : boolean := false;

begin

  clk <= not clk after clk_period/2;
  rstn <= not rst;

  main: process
    procedure run_test is begin
      info("Init test");
      wait until rising_edge(clk); start <= true;
      wait until rising_edge(clk); start <= false;
      wait until (done and saved and rising_edge(clk));
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

  stimuli: process
    variable last : std_logic;
  begin
    wait until start and rising_edge(clk);
    done <= false;
    wait until rising_edge(clk);

    m_I.load_csv(tb_path & csv_i);

    info("Sending m_I of size " & to_string(m_I.height) & "x" & to_string(m_I.width) & " to UUT...");

    for y in 0 to m_I.height-1 loop
      for x in 0 to m_I.width-1 loop
        wait until rising_edge(clk);
        if x = m_I.width-1 then last := '1'; else last := '0'; end if;
        push_axi_stream(net, master_axi_stream, std_logic_vector(to_signed(m_I.get(x,y), data_width)) , tlast => last);
      end loop;
    end loop;

    info("m_I sent!");

    wait until rising_edge(clk);
    done <= true;
  end process;

  save: process
    variable o : std_logic_vector(31 downto 0);
    variable last : boolean:=false;
  begin
    wait until start and rising_edge(clk);
    saved <= false;
    wait for 50*clk_period;

    m_O.init_2d(m_I.width, m_I.height, o'length, true);

    info("Receiving m_O of size " & to_string(m_O.height) & "x" & to_string(m_O.width) & " from UUT...");

    for y in 0 to m_O.height-1 loop
      for x in 0 to m_O.width-1 loop
        pop_stream(net, slave_stream, o, last);
        if (x = m_O.width-1) and (last=false) then
          error("Something went wrong. Last misaligned!");
        end if;
        m_O.set(x,y,to_integer(signed(o)));
      end loop;
    end loop;

    info("m_O read!");

    wait until rising_edge(clk);
    m_O.save_csv(tb_path & csv_o);

    info("m_O saved!");

    wait until rising_edge(clk);
    saved <= true;
  end process;

--

  vunit_axism: entity vunit_lib.axi_stream_master
  generic map (
    master => master_axi_stream)
  port map (
    aclk   => clk,
    tvalid => m_valid,
    tready => m_ready,
    tdata  => m_data,
    tlast  => m_last);

  vunit_axiss: entity vunit_lib.axi_stream_slave
  generic map (
    slave => slave_axi_stream)
  port map (
    aclk   => clk,
    tvalid => s_valid,
    tready => s_ready,
    tdata  => s_data,
    tlast  => s_last);

--

  uut: entity work.axis_buffer
  generic map (
    data_width => data_width,
    fifo_depth => 4
  )
  port map (
    s_axis_clk   => clk,
    s_axis_rstn  => rstn,
    s_axis_rdy   => m_ready,
    s_axis_data  => m_data,
    s_axis_valid => m_valid,
    s_axis_strb  => "1111",
    s_axis_last  => m_last,

    m_axis_clk   => clk,
    m_axis_rstn  => rstn,
    m_axis_valid => s_valid,
    m_axis_data  => s_data,
    m_axis_rdy   => s_ready,
    m_axis_strb  => open,
    m_axis_last  => s_last
  );

end architecture;
