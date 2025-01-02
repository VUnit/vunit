-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
library ieee;
use ieee.std_logic_1164.all;

entity dff is
  generic(
    width : positive := 8
  );
  port(
    clk : in std_logic;
    reset : in std_logic;
    d : in std_logic_vector(width - 1 downto 0);
    q : out std_logic_vector(width - 1 downto 0)
  );
end;

architecture rtl of dff is
begin
  process(clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        q <= (others => '0');
      else
        q <= d;
      end if;
    end if;
  end process;
end;

architecture behavioral of dff is
begin
  process
  begin
    wait until rising_edge(clk);
    q <= (others => '0') when reset else d;
  end process;
end;

