-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
  port(
    clk : in std_logic;
    op_a : in unsigned(7 downto 0);
    op_b : in unsigned(7 downto 0);
    dv_in : in std_logic;
    sum : out unsigned(8 downto 0);
    dv_out : out std_logic
  );
end entity adder;

architecture a of adder is
begin
  main : process is
  begin
    wait until rising_edge(clk);
    sum <= resize(op_a, sum) + resize(op_b, sum);
    dv_out <= dv_in;
  end process main;
end architecture a;
