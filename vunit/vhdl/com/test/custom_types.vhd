-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

use work.constants_pkg.all;
use work.more_constants_pkg.all;

package custom_types_pkg is
  type enum1_t is (red, green, blue);
  -- Commented type should be ignored, if not this will cause a compile error
--  type enum1_t is (foo,bar);

  type record1_t is record
    a       : natural;
    b, c, d : integer;
  end record record1_t;
  type record2_msg_type_t is (command);
  type record2_t is record
    msg_type : record2_msg_type_t;
    a        : natural;
    b, c, d  : integer;
    e        : std_logic;
  end record record2_t;
  type record3_t is record
    char : character;
  end record record3_t;
  type record4_t is record
    my_integer          : integer;
    my_real             : real;
    my_time             : time;
    my_boolean          : boolean;
    my_bit              : bit;
    my_std_ulogic       : std_ulogic;
    my_severity_level   : severity_level;
    my_file_open_status : file_open_status;
    my_file_open_kind   : file_open_kind;
    my_integer2         : integer;
  end record record4_t;
  type record5_t is record
    my_character         : character;
    my_string            : string(1 to 3);
    my_boolean_vector    : boolean_vector(1 to 3);
    my_bit_vector        : bit_vector(1 to 3);
    my_integer_vector    : integer_vector(1 to 3);
    my_real_vector       : real_vector(1 to 3);
    my_time_vector       : time_vector(1 to 3);
    my_std_ulogic_vector : std_ulogic_vector(1 to 3);
    my_complex           : complex;
    my_character2        : character;
  end record record5_t;
  type record6_t is record
    my_complex_polar  : complex_polar;
    my_bit_unsigned   : ieee.numeric_bit.unsigned(1 to 3);
    my_bit_signed     : ieee.numeric_bit.signed(1 to 3);
    my_std_unsigned   : ieee.numeric_std.unsigned(1 to 3);
    my_std_signed     : ieee.numeric_std.signed(1 to 3);
    my_ufixed         : ufixed(2 downto -2);
    my_sfixed         : sfixed(2 downto -2);
    my_float          : float64;
    my_complex_polar2 : complex_polar;
  end record record6_t;
  type record7_t is record
    r4 : record4_t;
    r5 : record5_t;
    r6 : record6_t;
  end record record7_t;
  type record8_msg_type_t is (read, write);
  type record8_t is record
    msg_type : record8_msg_type_t;
    addr     : natural;
    data     : natural;
  end record record8_t;    type int_2d_t is array (integer range <>, integer range <>) of integer;
  type record9_msg_type_t is (foo, bar);
  type record9_t is record
    msg_type : record9_msg_type_t;
    slv   : std_logic_vector(byte_msb downto byte_lsb);
    str   : string(1 to 3);
    int_2d : int_2d_t(1 to 2, 4 downto -1);
  end record record9_t;

  type array1_t is array (-2 to 2) of natural;
  type array2_t is array (2 downto -2) of natural;
  type array3_t is array (-2 to 2, -1 to 1) of natural;
  type array4_t is array (positive range <>) of natural;
  type array5_t is array (integer range <>, integer range <>) of natural;
  type fruit_t is (apple, banana, melon, kiwi, orange, papaya);
  type array6_t is array (fruit_t range <>) of natural;
--  type--array7_t is array (integer range <>, fruit_t range <>) of natural;
  type array8_t is array (2 * (3 - 4) to 2, -1 to -1 + 2) of natural;
  type array9_t is array (array1_t'range) of natural;
  type array10_t is array (array1_t'range, -1 to 1) of natural;


end package custom_types_pkg;
