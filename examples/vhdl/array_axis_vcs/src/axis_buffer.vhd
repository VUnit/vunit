-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

entity axis_buffer is
  generic (
    data_width : integer := 32;
    fifo_depth : integer := 0  -- ceiling of the log base 2 of the desired FIFO length
  );
  port (
    s_axis_clk   : in  std_logic;
    s_axis_rstn  : in  std_logic;
    s_axis_rdy   : out std_logic;
    s_axis_data  : in  std_logic_vector(data_width-1 downto 0);
    s_axis_valid : in  std_logic;
    s_axis_strb  : in  std_logic_vector((data_width/8)-1 downto 0);
    s_axis_last  : in  std_logic;

    m_axis_clk   : in  std_logic;
    m_axis_rstn  : in  std_logic;
    m_axis_valid : out std_logic;
    m_axis_data  : out std_logic_vector(data_width-1 downto 0);
    m_axis_rdy   : in  std_logic;
    m_axis_strb  : out std_logic_vector((data_width/8)-1 downto 0);
    m_axis_last  : out std_logic
  );
end axis_buffer;

architecture arch of axis_buffer is

  signal r, e, f, wr, rd, valid : std_logic;
  signal d, q : std_logic_vector(data_width+data_width/8 downto 0);

begin

  r <= (s_axis_rstn nand m_axis_rstn);

  fifo: entity work.fifo
    generic map (
      fifo_depth => fifo_depth,
      data_width => data_width+data_width/8+1
    )
    port map (
      CLKW => s_axis_clk,
      CLKR => m_axis_clk,
      RST => r,
      WR => wr,
      RD => rd,
      E => e,
      F => f,
      D => d,
      Q => q
    );

-- AXI4 Stream Slave logic

  wr <= s_axis_valid and (not f);
  d <= s_axis_last & s_axis_strb & s_axis_data;

  s_axis_rdy  <= not f;

-- AXI4 Stream Master logic

  rd <= (not e) and (valid nand (not m_axis_rdy));

  process(m_axis_clk) begin
    if rising_edge(m_axis_clk) then
      if ((not m_axis_rstn) or ((valid and E) and m_axis_rdy))='1' then
        valid <= '0';
      elsif rd then
        valid <= '1';
      end if;
    end if;
  end process;

  m_axis_valid <= valid;
  m_axis_last <= q(d'left);
  m_axis_strb <= q(q'left-1 downto data_width);
  m_axis_data <= q(data_width-1 downto 0);

end architecture;
