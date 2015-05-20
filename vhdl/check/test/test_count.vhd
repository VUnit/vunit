-- This package provides a counter object for VHDL 200x.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use work.test_types.all;

package test_count is
  impure function get_count
    return natural;

  impure function set_count(
    constant value : natural)
    return natural;

  impure function inc_count
    return natural;

  procedure inc_count;

  procedure reset_count;

  impure function get_count(
    constant index : in natural)
    return natural;

  impure function set_count(
    constant index : in natural;
    constant value : in natural)
    return natural;

  impure function inc_count(
    constant index : in natural)
    return natural;

  procedure inc_count(
    constant index : in natural);

  procedure reset_count(
    constant index : in natural);
end package test_count;

package body test_count is
  shared variable count : count_t;

  impure function get_count
    return natural is
  begin
    return count.get(1);
  end;

  impure function set_count (
    constant value : natural)
    return natural is
  begin
    return count.set(1, value);
  end;

  impure function inc_count
    return natural is
  begin
    return count.inc(1);
  end;

  procedure inc_count is
  begin
    count.inc(1);
  end;

  procedure reset_count is
  begin
    count.reset(1);
  end;

  impure function get_count(
    constant index : in natural)
    return natural is
  begin
    return count.get(index);
  end;

  impure function set_count(
    constant index : in natural;
    constant value : in natural)
    return natural is
  begin
    return count.set(index, value);
  end;

  impure function inc_count(
    constant index : in natural)
    return natural is
  begin
    return count.inc(index);
  end;

  procedure inc_count(
    constant index : in natural) is
  begin
    count.inc(index);
  end;

  procedure reset_count(
    constant index : in natural) is
  begin
    count.reset(index);
  end;

end package body test_count;
