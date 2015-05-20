-- This package contains basic types used in the checker test suites.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

package test_types is
  type count_t is protected
    impure function get(
      constant index : in natural)
      return natural;
    impure function set(
      constant index : in natural;
      constant value : in natural)
      return natural;
    impure function inc(
      constant index : in natural)
      return natural;
    procedure inc(
      constant index : in natural);
    procedure reset(
      constant index : in natural);
  end protected count_t;
end package test_types;

package body test_types is
  type count_t is protected body
    type natural_vector is array (natural range <>) of natural;
    variable count : natural_vector(0 to 9) := (others => 0);

    impure function get(
      constant index : in natural)
      return natural is
    begin
      return count(index);
    end;

    impure function set(
      constant index : in natural;
      constant value : in natural)
      return natural is
    begin
      count(index) := value;
      return count(index);
    end;

    impure function inc(
      constant index : in natural)
      return natural is
    begin
      count(index) := count(index) + 1;
      return count(index);
    end;

    procedure inc(
      constant index : in natural) is
    begin
      count(index) := count(index) + 1;
    end;

    procedure reset(
      constant index : in natural) is
    begin
      count(index) := 0;
    end;
  end protected body count_t;

end package body test_types;
