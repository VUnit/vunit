-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.math_real.all;

package util_pkg is
  -- ceiling of 2:s logarithm of value
  function clog2(value : natural) return natural;

  -- return true if value is an exact power of two
  function is_power_of_two(value : natural) return boolean;
end package;

package body util_pkg is
  function clog2(value : natural) return natural is
  begin
    return integer(ceil(log2(real(value))));
  end;

  function log2(value : natural) return natural is
  begin
    return integer(trunc(log2(real(value))));
  end;

  function is_power_of_two(value : natural) return boolean is
  begin
    return clog2(value) = log2(value);
  end;
end package body;
