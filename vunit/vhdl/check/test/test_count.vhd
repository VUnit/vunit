-- This package provides a counter object for VHDL 93.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.integer_vector_ptr_pkg.all;


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
  constant count : integer_vector_ptr_t := allocate(10);

  impure function get_count
    return natural is
  begin
    return get(count, 1);
  end;

  impure function set_count (
    constant value : natural)
    return natural is
  begin
    set(count, 1, value);
    return get(count, 1);
  end;

  impure function inc_count
    return natural is
  begin
    set(count, 1, get(count, 1) + 1);
    return get(count, 1);
  end;

  procedure inc_count is
  begin
    set(count, 1, get(count, 1) + 1);
  end;

  procedure reset_count is
  begin
    set(count, 1, 0);
  end;

  impure function get_count(
    constant index : in natural)
    return natural is
  begin
    return get(count, index);
  end;

  impure function set_count(
    constant index : in natural;
    constant value : in natural)
    return natural is
  begin
    set(count, index, value);
    return get(count, index);
  end;

  impure function inc_count(
    constant index : in natural)
    return natural is
  begin
    set(count, index, get(count, index) + 1);
    return get(count, index);
  end;

  procedure inc_count(
    constant index : in natural) is
  begin
    set(count, index, get(count, index) + 1);
  end;

  procedure reset_count(
    constant index : in natural) is
  begin
    set(count, index, 0);
  end;

end package body test_count;
