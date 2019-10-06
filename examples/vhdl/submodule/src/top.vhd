-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library adder;

entity top is
  generic (
      BITS : positive);
  port(
    clk : in std_logic;
    op_a : in unsigned(BITS - 1 downto 0);
    op_b : in unsigned(BITS - 1 downto 0);
    sum : out unsigned(BITS - 1 downto 0)
  );
end entity;

architecture arch of top is
begin

  adder_inst: entity adder.adder
    generic map(
      BITS => BITS
    )
    port map(
      clk => clk,
      op_a => op_a,
      op_b => op_b,
      sum => sum
    );

end architecture;
