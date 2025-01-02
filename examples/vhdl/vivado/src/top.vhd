-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library xil_defaultlib;

-- A simple entity just for example
entity top is
  port (
    clk : in std_logic;
    rstn : in std_logic;
    in_valid : in std_logic;
    in_ready : out std_logic;
    in_data : in std_logic_vector(7 downto 0);
    out_valid : out std_logic;
    out_ready : in std_logic;
    out_data : out std_logic_vector(7 downto 0));
end entity;


architecture arch of top is
  component fifo_8b_32w is
    port (
      s_aclk        : IN  STD_LOGIC;
      s_aresetn     : IN  STD_LOGIC;
      s_axis_tvalid : IN  STD_LOGIC;
      s_axis_tready : OUT STD_LOGIC;
      s_axis_tdata  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axis_tvalid : OUT STD_LOGIC;
      m_axis_tready : IN  STD_LOGIC;
      m_axis_tdata  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
  end component fifo_8b_32w;
begin
  -- Just pass through data to prove that component is not a black box
  -- and that compiled ip simulation model is used
  fifo_8b_32w_inst : component fifo_8b_32w
    port map (
      s_aclk        => clk,
      s_aresetn     => rstn,
      s_axis_tvalid => in_valid,
      s_axis_tready => in_ready,
      s_axis_tdata  => in_data,
      m_axis_tvalid => out_valid,
      m_axis_tready => out_ready,
      m_axis_tdata  => out_data);
end architecture;
