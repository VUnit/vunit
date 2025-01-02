-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Optional package that includes random functions for the data_types based on
-- OSVVM

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;

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
                                      bits_per_word : positive;
                                      is_signed : boolean);

  impure function random_integer_vector_ptr(length : natural;
                                            bits_per_word : positive;
                                            is_signed : boolean) return integer_vector_ptr_t;

  procedure random_integer_array(variable rnd : inout RandomPType;
                                 variable integer_array : inout integer_array_t;
                                 width : natural := 1;
                                 height : natural := 1;
                                 depth : natural := 1;
                                 min_value : integer := 0;
                                 max_value : integer := 0);

  procedure random_integer_array(variable rnd : inout RandomPType;
                                 variable integer_array : inout integer_array_t;
                                 width : natural := 1;
                                 height : natural := 1;
                                 depth : natural := 1;
                                 bits_per_word : integer := 1;
                                 is_signed : boolean := false);

  impure function random_integer_array(width : natural := 1;
                                       height : natural := 1;
                                       depth : natural := 1;
                                       min_value : integer := 0;
                                       max_value : integer := 0) return integer_array_t;

  impure function random_integer_array(width : natural := 1;
                                       height : natural := 1;
                                       depth : natural := 1;
                                       bits_per_word : integer := 1;
                                       is_signed : boolean := false) return integer_array_t;
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
      integer_vector_ptr := new_integer_vector_ptr(length);
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
                                      bits_per_word : positive;
                                      is_signed : boolean) is
  begin
    if is_signed then
      random_integer_vector_ptr(rnd, integer_vector_ptr, length, -(2**(bits_per_word-1)), 2**(bits_per_word-1)-1);
    else
      random_integer_vector_ptr(rnd, integer_vector_ptr, length, 0, 2**bits_per_word-1);
    end if;
  end;

  impure function random_integer_vector_ptr(length : natural;
                                            bits_per_word : positive;
                                            is_signed : boolean) return integer_vector_ptr_t is
    variable integer_vector_ptr : integer_vector_ptr_t;
  begin
    random_integer_vector_ptr(random_ptype, integer_vector_ptr, length, bits_per_word, is_signed);
    return integer_vector_ptr;
  end;

  function ilog2(value : natural) return natural is
    variable res : natural := 0;
    variable pow : natural := 1;
  begin
    while pow < value loop
      pow := pow*2;
      res := res + 1;
    end loop;
    return res;
  end function;

  procedure random_integer_array(variable rnd : inout RandomPType;
                                 variable integer_array : inout integer_array_t;
                                 width : natural := 1;
                                 height : natural := 1;
                                 depth : natural := 1;
                                 min_value : integer := 0;
                                 max_value : integer := 0) is
    variable bit_width : integer;
    variable is_signed : boolean;
  begin
    assert min_value <= max_value report "min_value must be lower or equal to max_value";
    is_signed := min_value < 0;

    if is_signed then
      bit_width := ilog2(abs min_value) + 1;
    else
      bit_width := ilog2(max_value+1);
    end if;

    deallocate(integer_array);
    integer_array := new_3d(width => width, height => height, depth => depth,
                            bit_width => bit_width, is_signed => is_signed);

    for i in 0 to integer_array.length-1 loop
      set(integer_array, i, rnd.RandInt(min_value, max_value));
    end loop;
  end procedure;

  procedure random_integer_array(variable rnd : inout RandomPType;
                                 variable integer_array : inout integer_array_t;
                                 width : natural := 1;
                                 height : natural := 1;
                                 depth : natural := 1;
                                 bits_per_word : integer := 1;
                                 is_signed : boolean := false) is
    variable min_value, max_value : integer;
  begin
    if is_signed then
      min_value := -2**(bits_per_word-1);
      max_value := 2**(bits_per_word-1)-1;
    else
      min_value := 0;
      max_value := 2**bits_per_word-1;
    end if;
    random_integer_array(rnd, integer_array, width, height, depth,
                         min_value => min_value, max_value => max_value);
  end procedure;

  impure function random_integer_array(width : natural := 1;
                                       height : natural := 1;
                                       depth : natural := 1;
                                       min_value : integer := 0;
                                       max_value : integer := 0) return integer_array_t is
    variable integer_array : integer_array_t;
  begin
    random_integer_array(random_ptype, integer_array, width, height, depth, min_value, max_value);
    return integer_array;
  end;

  impure function random_integer_array(width : natural := 1;
                                       height : natural := 1;
                                       depth : natural := 1;
                                       bits_per_word : integer := 1;
                                       is_signed : boolean := false) return integer_array_t is
    variable integer_array : integer_array_t;
  begin
    random_integer_array(random_ptype, integer_array, width, height, depth, bits_per_word, is_signed);
    return integer_array;
  end;

end package body;
