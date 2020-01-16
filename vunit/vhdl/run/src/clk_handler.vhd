-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.clk_pkg.all;
use work.integer_vector_ptr_pkg.all;

entity clk_handler is
  generic (
    p: integer_vector_ptr_t;
    clks: periods_t := periods_def
  );
  port (
    rst: in std_logic;
    clk: out std_logic;
    tg: out boolean;
    sel: in natural := 2
  );
end;

architecture arch of clk_handler is
  signal s, x: std_logic := '0';
begin
  s <= not s after (clks(sel)/2);
  run: process(s)
    variable c: clk_t := clk_min;
    variable t: clk_t := clk_max;
  begin
    if rising_edge(s) then
      t := get_clk(p);
      if rst='1' then
        c := clk_min;
      elsif c < t then
        inc(c);
      end if;
    end if;
    x <= c < t;
    clk <= s and c < t;
    tg <= rst='0' and c = t;
  end process;
end;
