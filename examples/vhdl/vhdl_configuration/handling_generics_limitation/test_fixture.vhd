-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

entity test_fixture is
  generic(
    width : positive := 8;
    clk_period : time
  );
  port(
    clk : out std_logic := '0';
    reset : in std_logic;
    d : in std_logic_vector(width - 1 downto 0);
    q : out std_logic_vector(width - 1 downto 0)
  );
end entity;

architecture tb of test_fixture is
begin
  clk <= not clk after clk_period / 2;

  dut : entity work.dff(rtl)
    generic map(
      width => width
    )
    port map(
      clk => clk,
      reset => reset,
      d => d,
      q => q
    );

end architecture;
