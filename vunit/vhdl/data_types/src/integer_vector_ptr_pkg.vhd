-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

--
-- The purpose of this package is to provide an integer vector access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of integer vector access types.
--

package integer_vector_ptr_pkg is
  subtype index_t is integer range -1 to integer'high;
  type integer_vector_ptr_t is record
    index : index_t;
  end record;
  constant null_ptr : integer_vector_ptr_t := (index => -1);

  function to_integer(value : integer_vector_ptr_t) return integer;
  impure function to_integer_vector_ptr(value : integer) return integer_vector_ptr_t;
  impure function allocate(length : natural := 0; value : integer := 0) return integer_vector_ptr_t;
  procedure deallocate(ptr : integer_vector_ptr_t);
  impure function length(ptr : integer_vector_ptr_t) return integer;
  procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer);
  impure function get(ptr : integer_vector_ptr_t; index : integer) return integer;
  procedure reallocate(ptr : integer_vector_ptr_t; length : natural; value : integer := 0);
  procedure resize(ptr : integer_vector_ptr_t; length : natural; drop : natural := 0; value : integer := 0);

end package;
