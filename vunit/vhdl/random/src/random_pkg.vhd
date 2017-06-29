-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Optional package that includes random functions for the data_types based on
-- OSVVM

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.integer_vector_ptr_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

package random_pkg is
  procedure random_integer_vector_ptr(variable rnd : inout RandomPType;
                                      variable integer_vector_ptr : inout integer_vector_ptr_t;
                                      length : natural;
                                      min_value : integer;
                                      max_value : integer);

  impure function random_integer_vector_ptr(length : natural;
                                            min_value : integer;
                                            max_value : integer) return integer_vector_ptr_t;

  procedure random_integer_vector_ptr(variable rnd : inout RandomPType;
                                      variable integer_vector_ptr : inout integer_vector_ptr_t;
                                      length : natural;
                                      num_bits : positive;
                                      is_signed : boolean);

  impure function random_integer_vector_ptr(length : natural;
                                            num_bits : positive;
                                            is_signed : boolean) return integer_vector_ptr_t;
end package;

package body random_pkg is
  shared variable random_ptype : RandomPType;

  procedure random_integer_vector_ptr(variable rnd : inout RandomPType;
                                      variable integer_vector_ptr : inout integer_vector_ptr_t;
                                      length : natural;
                                      min_value : integer;
                                      max_value : integer) is
  begin
    if integer_vector_ptr = null_ptr then
      integer_vector_ptr := allocate(length);
    else
      reallocate(integer_vector_ptr, length);
    end if;
    for i in 0 to length-1 loop
      set(integer_vector_ptr, i, rnd.RandInt(min_value, max_value));
    end loop;
  end procedure;

  impure function random_integer_vector_ptr(length : natural;
                                            min_value : integer;
                                            max_value : integer) return integer_vector_ptr_t is
    variable integer_vector_ptr : integer_vector_ptr_t;
  begin
    random_integer_vector_ptr(random_ptype, integer_vector_ptr, length, min_value, max_value);
    return integer_vector_ptr;
  end function;

  procedure random_integer_vector_ptr(variable rnd : inout RandomPType;
                                      variable integer_vector_ptr : inout integer_vector_ptr_t;
                                      length : natural;
                                      num_bits : positive;
                                      is_signed : boolean) is
  begin
    if is_signed then
      random_integer_vector_ptr(rnd, integer_vector_ptr, length, -(2**(num_bits-1)), 2**(num_bits-1)-1);
    else
      random_integer_vector_ptr(rnd, integer_vector_ptr, length, 0, 2**num_bits-1);
    end if;
  end;

  impure function random_integer_vector_ptr(length : natural;
                                            num_bits : positive;
                                            is_signed : boolean) return integer_vector_ptr_t is
    variable integer_vector_ptr : integer_vector_ptr_t;
  begin
    random_integer_vector_ptr(random_ptype, integer_vector_ptr, length, num_bits, is_signed);
    return integer_vector_ptr;
  end;

end package body;
