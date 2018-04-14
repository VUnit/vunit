-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

entity axis_buffer is
  generic (
    C_DATA_WIDTH      : integer := 32;
    C_FIFO_DEPTH_BITS : integer := 0  -- ceiling of the log base 2 of the desired FIFO length
  );
  port (
    S_AXIS_CLK   : in  std_logic;
    S_AXIS_RSTN  : in  std_logic;
    S_AXIS_RDY   : out std_logic;
    S_AXIS_DATA  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
    S_AXIS_VALID : in  std_logic;
    S_AXIS_STRB  : in  std_logic_vector((C_DATA_WIDTH/8)-1 downto 0);
    S_AXIS_LAST  : in  std_logic;

    M_AXIS_CLK   : in  std_logic;
    M_AXIS_RSTN  : in  std_logic;
    M_AXIS_VALID : out std_logic;
    M_AXIS_DATA  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
    M_AXIS_RDY   : in  std_logic;
    M_AXIS_STRB  : out std_logic_vector((C_DATA_WIDTH/8)-1 downto 0);
    M_AXIS_LAST  : out std_logic
  );
end axis_buffer;

architecture arch of axis_buffer is

  signal r, e, f, wr, rd, valid : std_logic;
  signal d, q : std_logic_vector(C_DATA_WIDTH+C_DATA_WIDTH/8 downto 0);

begin

  r <= (S_AXIS_RSTN nand M_AXIS_RSTN);

  fifo: entity work.fifo
    generic map (
      C_FIFO_DEPTH_BITS => C_FIFO_DEPTH_BITS,
      C_DATA_WIDTH => C_DATA_WIDTH+C_DATA_WIDTH/8+1
    )
    port map (
      CLKW => S_AXIS_CLK,
      CLKR => M_AXIS_CLK,
      RST => r,
      WR => wr,
      RD => rd,
      E => e,
      F => f,
      D => d,
      Q => q
    );

-- AXI4 Stream Slave logic

  wr <= S_AXIS_VALID and (not f);
  d <= S_AXIS_LAST & S_AXIS_STRB & S_AXIS_DATA;

  S_AXIS_RDY  <= not f;

-- AXI4 Stream Master logic

  rd <= (not e) and (valid nand (not M_AXIS_RDY));

  process(M_AXIS_CLK) begin
    if rising_edge(M_AXIS_CLK) then
      if ((not M_AXIS_RSTN) or ((valid and E) and M_AXIS_RDY))='1' then
        valid <= '0';
      elsif rd then
        valid <= '1';
      end if;
    end if;
  end process;

  M_AXIS_VALID <= valid;
  M_AXIS_LAST <= q(d'left);
  M_AXIS_STRB <= q(q'left-1 downto C_DATA_WIDTH);
  M_AXIS_DATA <= q(C_DATA_WIDTH-1 downto 0);

end architecture;
