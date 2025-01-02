-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- This testbench is a Minimum Working Example (MWE) of VUnit's resources to read/write CSV files and to verify
-- AXI4-Stream components. A CSV file that contains comma separated integers is read from `data_path & csv_i`, and it is
-- sent row by row to an AXI4-Stream Slave. The AXI4-Stream Slave is expected to be connected to an AXI4-Stream Master
-- either directly or (preferredly) through a FIFO, thus composing a loopback. Therefore, as data is pushed to the
-- AXI4-Stream Slave interface, the output is read from the AXI4-Stream Master interface and it is saved to
-- `data_path & csv_o`.
-- AXI Stream VC's optional 'stall' feature is used for generating random stalls in the interfaces. In this example,
-- a 5% of probability to stall for a duration of 1 to 10 cycles is defined.

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

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

  constant clk_period : time    := 20 ns;
  constant data_width : natural := 32;

  -- AXI4Stream Verification Components

  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(
    data_length => data_width,
    stall_config => new_stall_config(0.05, 1, 10)
  );
  constant slave_axi_stream  : axi_stream_slave_t  := new_axi_stream_slave(
    data_length => data_width,
    stall_config => new_stall_config(0.05, 1, 10)
  );

  -- tb signals and variables

  signal clk, rst, rstn : std_logic := '0';
  constant m_I : integer_array_t := load_csv(tb_path & csv_i);
  constant m_O : integer_array_t := new_2d(width(m_I), height(m_I), data_width, true);
  signal start, done, saved : boolean := false;

begin

  clk <= not clk after clk_period/2;
  rstn <= not rst;

  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        rst <= '1';
        wait for 15*clk_period;
        rst <= '0';
        info("Init test");
        wait until rising_edge(clk);
        start <= true;
        wait until rising_edge(clk);
        start <= false;
        wait until (done and saved and rising_edge(clk));
        info("Test done");
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

    info("Sending m_I of size " & to_string(height(m_I)) & "x" & to_string(width(m_I)) & " to UUT...");

    for y in 0 to height(m_I)-1 loop
      for x in 0 to width(m_I)-1 loop
        wait until rising_edge(clk);
        if x = width(m_I)-1 then last := '1'; else last := '0'; end if;
        push_axi_stream(net, master_axi_stream, std_logic_vector(to_signed(get(m_I, x, y), data_width)) , tlast => last);
      end loop;
    end loop;

    info("m_I sent!");

    wait until rising_edge(clk);
    done <= true;
  end process;

  save: process
    variable o : std_logic_vector(31 downto 0);
    variable last : std_logic:='0';
  begin
    wait until start and rising_edge(clk);
    saved <= false;
    wait for 50*clk_period;

    info("Receiving m_O of size " & to_string(height(m_O)) & "x" & to_string(width(m_O)) & " from UUT...");

    for y in 0 to height(m_O)-1 loop
      for x in 0 to width(m_O)-1 loop
        pop_axi_stream(net, slave_axi_stream, tdata => o, tlast => last);
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
  end process;

--

  uut_vc: entity work.vc_axis
  generic map (
    m_axis => master_axi_stream,
    s_axis => slave_axi_stream,
    data_width => data_width
  )
  port map (
    clk  => clk,
    rstn => rstn
  );

end architecture;
