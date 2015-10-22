-- This file provides the implementation for the test type methods. This
-- version is for VHDL 2002 and 2008.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use work.test_types.all;

package body test_type_methods is
  procedure get (
    variable sint : inout shared_natural;
    variable value : out natural) is
  begin
    value := sint.get;
  end;

  procedure set (
    variable sint : inout shared_natural;
    constant value : natural) is
  begin
    sint.set(value);
  end;

  procedure add (
    variable sint : inout shared_natural;
    constant value : natural) is
  begin
    sint.add(value);
  end;
end package body test_type_methods;
