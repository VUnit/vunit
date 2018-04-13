-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

entity fifo is
  generic (
    C_DATA_WIDTH      : positive := 8;
    C_FIFO_DEPTH_BITS : positive := 8
  );
  port (
    CLKW : in std_logic;
    CLKR : in std_logic;
    RST  : in std_logic;
    WR   : in std_logic;
    RD   : in std_logic;
    D    : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
    E    : out std_logic;
    F    : out std_logic;
    Q    : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
  );
end fifo;

architecture arch of fifo is

  type t_fifo is array (0 to 2**C_FIFO_DEPTH_BITS-1)
    of std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal mem : t_fifo;

  signal rdp, wrp : unsigned(C_FIFO_DEPTH_BITS downto 0);

begin

-- Assertions
  process(CLKW, CLKR)
    constant dx : std_logic_vector(D'left downto 0) := (others => 'X');
    constant du : std_logic_vector(D'left downto 0) := (others => 'U');
  begin
    if rising_edge(CLKW) then
      if ( WR and ( D?=dx or D?=du ) ) then
        assert false report "Wrote X|U to FIFO" severity failure;
      end if;
      if (F and WR) then
        assert false report "Wrote to FIFO while Full" severity failure;
      end if;
    end if;
    if rising_edge(CLKR) then
      if (E and RD) then
        assert false report "Read from FIFO while Empty" severity failure;
      end if;
    end if;
  end process;

--

  process(CLKW) begin
    if rising_edge(CLKW) then
      if WR then
        mem(to_integer(wrp(C_FIFO_DEPTH_BITS-1 downto 0))) <= D;
      end if;
    end if;
  end process;

  process(CLKW) begin
    if rising_edge(CLKW) then
      if RST then
        wrp <= (others => '0');
      else
        if WR then
          wrp <= wrp+1;
        end if;
      end if;
    end if;
  end process;

  F <= rdp(C_FIFO_DEPTH_BITS-1 downto 0)?=wrp(C_FIFO_DEPTH_BITS-1 downto 0)
       and (rdp(C_FIFO_DEPTH_BITS) xor wrp(C_FIFO_DEPTH_BITS));
  E <= rdp ?= wrp;

  process(CLKR) begin
    if rising_edge(CLKR) then
      if RST then
        Q <= (others => '0');
      elsif RD then
        Q <= mem(to_integer(rdp(C_FIFO_DEPTH_BITS-1 downto 0)));
      end if;
    end if;
  end process;

  process(CLKR) begin
    if rising_edge(CLKR) then
      if RST then
        rdp <= (others => '0');
      else
        if RD then rdp <= rdp+1; end if;
      end if;
    end if;
  end process;

end arch;

---

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
