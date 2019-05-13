-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;

package clk_pkg is
  type periods_t is array (natural range 0 to 7) of time;

  constant periods_def: periods_t := (83.3 ns, 50 ns, 20 ns, 16.7 ns, 14.3 ns, 12.5 ns, 11.1 ns, 10 ns);

  type clk_t is array (natural range 0 to 1) of integer;

  constant clk_min: clk_t := (others => integer'low);
  constant clk_max: clk_t := (others => integer'high);

  procedure set_clk (
    p: integer_vector_ptr_t;
    t: clk_t
  );

  impure function get_clk (
      p: integer_vector_ptr_t
  ) return clk_t;

  function to_std_logic (
    i: boolean
  ) return std_logic;

  function "+" (
    l: clk_t;
    i: integer
  ) return clk_t;

  function "<" (
    l, r: clk_t
  ) return boolean;

  function "=" (
    l, r: clk_t
  ) return boolean;

  function "<" (
    l, r: clk_t
  ) return std_logic;

  function "=" (
    l, r: clk_t
  ) return std_logic;

  impure function to_string (
    t: clk_t
  ) return string;

  procedure inc (
    variable t: inout clk_t
  );

  procedure wait_for (
    signal clk: in std_logic;
    i: integer
  );

  procedure wait_load (
    constant ptr: integer_vector_ptr_t;
    hold: time := 10 ns
  );

  procedure wait_sync (
    constant ptr: integer_vector_ptr_t;
    signal condition, trigger: in boolean;
    hold: time := 10 ns
  );
end package;

package body clk_pkg is
  procedure set_clk (
    p: integer_vector_ptr_t;
    t: clk_t
  ) is begin
    set(p, 0, t(0));
    set(p, 1, t(1));
  end;

  impure function get_clk (
    p: integer_vector_ptr_t
  ) return clk_t is
    variable t: clk_t;
  begin
    t(0) := get(p, 0);
    t(1) := get(p, 1);
    return t;
  end;

  function to_std_logic (
    i: boolean
  ) return std_logic is begin
    if i then
      return '1';
    else
      return '0';
    end if;
  end;

  function "+" (
    l: clk_t;
    i: integer
  ) return clk_t is
    variable x: clk_t := (0 => i, 1=> l(1));
  begin
    if (l(0) > 0) and (i > integer'high-l(0)) then
      x(0) := x(0) + integer'low - (integer'high-l(0));
      assert x(1) < integer'high report "Cannot add; result out of bounds." severity error;
      x(1) := x(1) + 1;
    else
      x(0) := x(0) + l(0);
    end if;
    return x;
  end;

  function "<" (
    l, r: clk_t
  ) return boolean is begin
    if l(1) /= r(1) then
      return l(1) < r(1);
    else
      return l(0) < r(0);
    end if;
  end;

  function "=" (
    l, r: clk_t
  ) return boolean is begin
    return (l(0) = r(0)) and (l(1) = r(1));
  end;

  function "<"(l, r: clk_t) return std_logic is begin return to_std_logic(l<r); end;
  function "="(l, r: clk_t) return std_logic is begin return to_std_logic(l=r); end;

  impure function to_string (
    t: clk_t
  ) return string is begin
    return integer'image(t(0)) & " " & integer'image(t(1));
  end;

  procedure inc (
    variable t: inout clk_t
  ) is begin
    if t(0) = integer'high then
      t(0) := 0;
      if t(1) = integer'high then
        t(1) := 0;
      else
        t(1) := t(1)+1;
      end if;
    else
      t(0) := t(0)+1;
    end if;
  end;

  procedure wait_for (
    signal clk: in std_logic;
    i: integer
  ) is begin
    for x in 0 to i-1 loop
      wait until rising_edge(clk);
    end loop;
  end;

  procedure wait_load (
    constant ptr: integer_vector_ptr_t;
    hold: time := 10 ns
  ) is begin
    while get(ptr, 3) /= 0 loop
      wait for hold;
    end loop;
  end;

  procedure wait_sync (
    constant ptr: integer_vector_ptr_t;
    signal condition, trigger: in boolean;
    hold: time := 10 ns
  ) is begin
    while not condition loop
      wait until trigger'event and trigger=true;
      if get(ptr, 2) /= 0 then
        wait for hold;
        set_clk(ptr, get_clk(ptr)+get(ptr, 2));
      else
        wait until trigger'event and trigger=false;
      end if;
    end loop;
    set(ptr, 3, 2);
  end;
end;
