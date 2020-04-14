-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

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
context vunit_lib.vc_context;

entity tb_py_axis_loop is
  generic (
    runner_cfg : string;
    tb_path    : string;
    csv_i      : string := "data/in.csv";
    csv_o      : string := "data/out.csv"
  );
end entity;

architecture tb of tb_py_axis_loop is

  -- Simulation constants

  constant clk_period : time    := 20 ns;
  constant data_width : natural := 32;

  -- AXI4Stream Verification Components

  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(data_length => data_width);
  constant slave_axi_stream  : axi_stream_slave_t  := new_axi_stream_slave(data_length => data_width);
  constant m_axis : axi_stream_master_t := new_axi_stream_master(data_length => data_width);
  constant s_axis : axi_stream_slave_t := new_axi_stream_slave(data_length => data_width);

  -- tb signals and variables

  signal clk, rst, rstn : std_logic := '0';
  constant m_I : integer_array_t := load_csv(tb_path & csv_i);
  constant m_O : integer_array_t := new_2d(width(m_I), height(m_I), data_width, true);
  signal start, sent, saved : boolean := false;

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

    info("Sending m_I of size " & to_string(height(m_I)) & "x" & to_string(width(m_I)) & " to UUT...");

    for y in 0 to height(m_I)-1 loop
      for x in 0 to width(m_I)-1 loop
        wait until rising_edge(clk);
        if x = width(m_I)-1 then last := '1'; else last := '0'; end if;
        push_axi_stream(net, m_axis, std_logic_vector(to_signed(get(m_I, x, y), data_width)) , tlast => last);
      end loop;
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

    info("Receiving m_O of size " & to_string(height(m_O)) & "x" & to_string(width(m_O)) & " from UUT...");

    for y in 0 to height(m_O)-1 loop
      for x in 0 to width(m_O)-1 loop
        pop_axi_stream(net, s_axis, tdata => o, tlast => last);
        if (x = width(m_O)-1) and (last='0') then
          error("Something went wrong. Last misaligned!");
        end if;
        set(m_O, x, y, to_integer(signed(o)));
      end loop;
    end loop;

    info("m_O read!");

    wait until rising_edge(clk);
    save_csv(m_O, tb_path & csv_o);

    info("m_O saved!");

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
      fifo_depth => 4
    )
    port map (
      clk  => clk,
      rstn => rstn
    );

end architecture;
