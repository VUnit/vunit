-- This package provides a counter object for VHDL 93.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

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
  type natural_vector is array (natural range <>) of natural;
  shared variable count : natural_vector(0 to 9) := (others => 0);

  impure function get_count
    return natural is
  begin
    return count(1);
  end;

  impure function set_count (
    constant value : natural)
    return natural is
  begin
    count(1) := value;
    return count(1);
  end;

  impure function inc_count
    return natural is
  begin
    count(1) := count(1) + 1;
    return count(1);
  end;

  procedure inc_count is
  begin
    count(1) := count(1) + 1;
  end;

  procedure reset_count is
  begin
    count(1) := 0;
  end;

  impure function get_count(
    constant index : in natural)
    return natural is
  begin
    return count(index);
  end;

  impure function set_count(
    constant index : in natural;
    constant value : in natural)
    return natural is
  begin
    count(index) := value;
    return count(index);
  end;

  impure function inc_count(
    constant index : in natural)
    return natural is
  begin
    count(index) := count(index) + 1;
    return count(index);
  end;

  procedure inc_count(
    constant index : in natural) is
  begin
    count(index) := count(index) + 1;
  end;

  procedure reset_count(
    constant index : in natural) is
  begin
    count(index) := 0;
  end;

end package body test_count;
