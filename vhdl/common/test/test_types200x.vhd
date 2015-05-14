-- This package provides various types useful in testbenches. This version is
-- for VHDL 2002 and 2008
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package test_types is
  type shared_natural is protected
    impure function get
      return natural;
    procedure set (
      constant value : in natural);
    procedure add (
      constant value : in natural);
  end protected shared_natural;
end package test_types;

package body test_types is
  type shared_natural is protected body
    variable int : natural;

    impure function get
      return natural is
    begin
      return int;
    end;

    procedure set (
      constant value : in natural) is
    begin
      int := value;
    end;

    procedure add (
      constant value : in natural) is
    begin
      int := int + value;
    end;
  end protected body shared_natural;
end package body test_types;
