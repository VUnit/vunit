-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

entity fifo is
  generic (
    data_width : positive := 8;
    fifo_depth : positive := 8
  );
  port (
    clkw : in std_logic;
    clkr : in std_logic;
    rst  : in std_logic;
    wr   : in std_logic;
    rd   : in std_logic;
    d    : in std_logic_vector(data_width-1 downto 0);
    e    : out std_logic;
    f    : out std_logic;
    q    : out std_logic_vector(data_width-1 downto 0)
  );
end fifo;

architecture arch of fifo is

  type fifo_t is array (0 to 2**fifo_depth-1)
    of std_logic_vector(data_width-1 downto 0);
  signal mem : fifo_t;

  signal rdp, wrp : unsigned(fifo_depth downto 0);

begin

  -- If your simulator chokes on the following block,
  -- see https://electronics.stackexchange.com/questions/540769/what-kind-of-vhdl-process-is-this/
  PslChecks : block is
  begin
    assert always (not rst and wr -> not is_x(d))@rising_edge(clkw)
      report "wrote X|U to FIFO";
    assert always (not rst and f -> not wr)@rising_edge(clkw)
      report "Wrote to FIFO while full";
    assert always (not rst and e -> not rd)@rising_edge(clkr)
      report "Read from FIFO while empty";
  end block PslChecks;

  process(clkw) begin
    if rising_edge(clkw) then
      if wr then
        mem(to_integer(wrp(fifo_depth-1 downto 0))) <= d;
      end if;
    end if;
  end process;

  process(clkw) begin
    if rising_edge(clkw) then
      if rst then
        wrp <= (others => '0');
      else
        if wr then
          wrp <= wrp+1;
        end if;
      end if;
    end if;
  end process;

  f <= rdp(fifo_depth-1 downto 0)?=wrp(fifo_depth-1 downto 0)
       and (rdp(fifo_depth) xor wrp(fifo_depth));
  e <= rdp ?= wrp;

  process(clkr) begin
    if rising_edge(clkr) then
      if rst then
        q <= (others => '0');
      elsif rd then
        q <= mem(to_integer(rdp(fifo_depth-1 downto 0)));
      end if;
    end if;
  end process;

  process(clkr) begin
    if rising_edge(clkr) then
      if rst then
        rdp <= (others => '0');
      else
        if rd then rdp <= rdp+1; end if;
      end if;
    end if;
  end process;

end arch;
