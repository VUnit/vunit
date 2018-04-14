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
