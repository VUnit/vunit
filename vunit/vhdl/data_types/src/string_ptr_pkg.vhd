-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com
--
-- The purpose of this package is to provide an string access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of string access types.
--

package string_ptr_pkg is
  subtype index_t is integer range -1 to integer'high;
  type string_ptr_t is record
    index : index_t;
  end record;
  constant null_string_ptr : string_ptr_t := (index => -1);

  function to_integer(value : string_ptr_t) return integer;
  impure function to_string_ptr(value : integer) return string_ptr_t;
  impure function allocate(length : natural := 0) return string_ptr_t;
  impure function allocate(value : string) return string_ptr_t;
  procedure deallocate(ptr : string_ptr_t);
  impure function length(ptr : string_ptr_t) return integer;
  procedure set(ptr : string_ptr_t; index : integer; value : character);
  impure function get(ptr : string_ptr_t; index : integer) return character;
  procedure reallocate(ptr : string_ptr_t; length : natural);
  procedure reallocate(ptr : string_ptr_t; value : string);
  procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0);
  impure function to_string(ptr : string_ptr_t) return string;
end package;
