-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.integer_array_pkg.all;

package queue_pkg is
  type queue_t is record
    p_meta : integer_vector_ptr_t;
    data   : string_ptr_t;
  end record;
  type queue_vec_t is array(integer range <>) of queue_t;
  constant null_queue : queue_t := (p_meta => null_ptr, data => null_string_ptr);

  impure function new_queue
  return queue_t;

  -- Returns the length of the queue in bytes
  impure function length (
    queue : queue_t
  ) return natural;

  impure function is_empty (
    queue : queue_t
  ) return boolean;

  procedure flush (
    queue : queue_t
  );

  impure function copy (
    queue : queue_t
  ) return queue_t;

  procedure push (
    queue : queue_t;
    value : integer
  );

  impure function pop (
    queue : queue_t
  ) return integer;

  procedure peek (
    queue : queue_t;
    variable value : out integer;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return integer;

  alias push_integer is push[queue_t, integer];
  alias pop_integer is pop[queue_t return integer];
  alias peek_integer is peek[queue_t, integer, natural];
  alias peek_integer is peek[queue_t return integer];

  procedure push_byte (
    queue : queue_t;
    value : natural range 0 to 255
  );

  impure function pop_byte (
    queue : queue_t
  ) return integer;

  procedure peek_byte (
    queue : queue_t;
    variable value : out integer;
    variable offset : inout natural
  );

  impure function peek_byte (
    queue : queue_t
  ) return integer;

  procedure push (
    queue : queue_t;
    value : character
  );

  impure function pop (
    queue : queue_t
  ) return character;

  procedure peek (
    queue : queue_t;
    variable value : out character;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return character;

  alias push_character is push[queue_t, character];
  alias pop_character is pop[queue_t return character];
  alias peek_character is peek[queue_t, character, natural];
  alias peek_character is peek[queue_t return character];

  procedure push (
    queue : queue_t;
    value : boolean
  );

  impure function pop (
    queue : queue_t
  ) return boolean;

  procedure peek (
    queue : queue_t;
    variable value : out boolean;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return boolean;

  alias push_boolean is push[queue_t, boolean];
  alias pop_boolean is pop[queue_t return boolean];
  alias peek_boolean is peek[queue_t, boolean, natural];
  alias peek_boolean is peek[queue_t return boolean];

  procedure push (
    queue : queue_t;
    value : real
  );

  impure function pop (
    queue : queue_t
  ) return real;

  procedure peek (
    queue : queue_t;
    variable value : out real;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return real;

  alias push_real is push[queue_t, real];
  alias pop_real is pop[queue_t return real];
  alias peek_real is peek[queue_t, real, natural];
  alias peek_real is peek[queue_t return real];

  procedure push (
    queue : queue_t;
    value : bit
  );

  impure function pop (
    queue : queue_t
  ) return bit;

  procedure peek (
    queue : queue_t;
    variable value : out bit;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return bit;

  alias push_bit is push[queue_t, bit];
  alias pop_bit is pop[queue_t return bit];
  alias peek_bit is peek[queue_t, bit, natural];
  alias peek_bit is peek[queue_t return bit];

  procedure push (
    queue : queue_t;
    value : std_ulogic
  );

  impure function pop (
    queue : queue_t
  ) return std_ulogic;

  procedure peek (
    queue : queue_t;
    variable value : out std_ulogic;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return std_ulogic;

  alias push_std_ulogic is push[queue_t, std_ulogic];
  alias pop_std_ulogic is pop[queue_t return std_ulogic];
  alias peek_std_ulogic is peek[queue_t, std_ulogic, natural];
  alias peek_std_ulogic is peek[queue_t return std_ulogic];

  procedure push (
    queue : queue_t;
    value : severity_level
  );

  impure function pop (
    queue : queue_t
  ) return severity_level;

  procedure peek (
    queue : queue_t;
    variable value : out severity_level;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return severity_level;

  alias push_severity_level is push[queue_t, severity_level];
  alias pop_severity_level is pop[queue_t return severity_level];
  alias peek_severity_level is peek[queue_t, severity_level, natural];
  alias peek_severity_level is peek[queue_t return severity_level];

  procedure push (
    queue : queue_t;
    value : file_open_status
  );

  impure function pop (
    queue : queue_t
  ) return file_open_status;

  procedure peek (
    queue : queue_t;
    variable value : out file_open_status;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return file_open_status;

  alias push_file_open_status is push[queue_t, file_open_status];
  alias pop_file_open_status is pop[queue_t return file_open_status];
  alias peek_file_open_status is peek[queue_t, file_open_status, natural];
  alias peek_file_open_status is peek[queue_t return file_open_status];

  procedure push (
    queue : queue_t;
    value : file_open_kind
  );

  impure function pop (
    queue : queue_t
  ) return file_open_kind;

  procedure peek (
    queue : queue_t;
    variable value : out file_open_kind;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return file_open_kind;

  alias push_file_open_kind is push[queue_t, file_open_kind];
  alias pop_file_open_kind is pop[queue_t return file_open_kind];
  alias peek_file_open_kind is peek[queue_t, file_open_kind, natural];
  alias peek_file_open_kind is peek[queue_t return file_open_kind];

  procedure push (
    queue : queue_t;
    value : bit_vector
  );

  impure function pop (
    queue : queue_t
  ) return bit_vector;

  procedure peek (
    queue : queue_t;
    variable value : out bit_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return bit_vector;

  alias push_bit_vector is push[queue_t, bit_vector];
  alias pop_bit_vector is pop[queue_t return bit_vector];
  alias peek_bit_vector is peek[queue_t, bit_vector, natural];
  alias peek_bit_vector is peek[queue_t return bit_vector];

  procedure push (
    queue : queue_t;
    value : std_ulogic_vector
  );

  impure function pop (
    queue : queue_t
  ) return std_ulogic_vector;

  procedure peek (
    queue : queue_t;
    variable value : out std_ulogic_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return std_ulogic_vector;

  alias push_std_ulogic_vector is push[queue_t, std_ulogic_vector];
  alias pop_std_ulogic_vector is pop[queue_t return std_ulogic_vector];
  alias peek_std_ulogic_vector is peek[queue_t, std_ulogic_vector, natural];
  alias peek_std_ulogic_vector is peek[queue_t return std_ulogic_vector];

  procedure push (
    queue : queue_t;
    value : complex
  );

  impure function pop (
    queue : queue_t
  ) return complex;

  procedure peek (
    queue : queue_t;
    variable value : out complex;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return complex;

  alias push_complex is push[queue_t, complex];
  alias pop_complex is pop[queue_t return complex];
  alias peek_complex is peek[queue_t, complex, natural];
  alias peek_complex is peek[queue_t return complex];

  procedure push (
    queue : queue_t;
    value : complex_polar
  );

  impure function pop (
    queue : queue_t
  ) return complex_polar;

  procedure peek (
    queue : queue_t;
    variable value : out complex_polar;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return complex_polar;

  alias push_complex_polar is push[queue_t, complex_polar];
  alias pop_complex_polar is pop[queue_t return complex_polar];
  alias peek_complex_polar is peek[queue_t, complex_polar, natural];
  alias peek_complex_polar is peek[queue_t return complex_polar];

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.unsigned
  );

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.unsigned;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_bit.unsigned;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_bit.unsigned;

  alias push_numeric_bit_unsigned is push[queue_t, ieee.numeric_bit.unsigned];
  alias pop_numeric_bit_unsigned is pop[queue_t return ieee.numeric_bit.unsigned];
  alias peek_numeric_bit_unsigned is peek[queue_t, ieee.numeric_bit.unsigned, natural];
  alias peek_numeric_bit_unsigned is peek[queue_t return ieee.numeric_bit.unsigned];

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.signed
  );

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.signed;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_bit.signed;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_bit.signed;

  alias push_numeric_bit_signed is push[queue_t, ieee.numeric_bit.signed];
  alias pop_numeric_bit_signed is pop[queue_t return ieee.numeric_bit.signed];
  alias peek_numeric_bit_signed is peek[queue_t, ieee.numeric_bit.signed, natural];
  alias peek_numeric_bit_signed is peek[queue_t return ieee.numeric_bit.signed];

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.unsigned
  );

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.unsigned;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_std.unsigned;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_std.unsigned;

  alias push_numeric_std_unsigned is push[queue_t, ieee.numeric_std.unsigned];
  alias pop_numeric_std_unsigned is pop[queue_t return ieee.numeric_std.unsigned];
  alias peek_numeric_std_unsigned is peek[queue_t, ieee.numeric_std.unsigned, natural];
  alias peek_numeric_std_unsigned is peek[queue_t return ieee.numeric_std.unsigned];

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.signed
  );

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.signed;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_std.signed;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_std.signed;

  alias push_numeric_std_signed is push[queue_t, ieee.numeric_std.signed];
  alias pop_numeric_std_signed is pop[queue_t return ieee.numeric_std.signed];
  alias peek_numeric_std_signed is peek[queue_t, ieee.numeric_std.signed, natural];
  alias peek_numeric_std_signed is peek[queue_t return ieee.numeric_std.signed];

  procedure push (
    queue : queue_t;
    value : string
  );

  impure function pop (
    queue : queue_t
  ) return string;

  procedure peek (
    queue : queue_t;
    variable value : out string;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return string;

  alias push_string is push[queue_t, string];
  alias pop_string is pop[queue_t return string];
  alias peek_string is peek[queue_t, string, natural];
  alias peek_string is peek[queue_t return string];

  procedure push (
    queue : queue_t;
    value : time
  );

  impure function pop (
    queue : queue_t
  ) return time;

  procedure peek (
    queue : queue_t;
    variable value : out time;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return time;

  alias push_time is push[queue_t, time];
  alias pop_time is pop[queue_t return time];
  alias peek_time is peek[queue_t, time, natural];
  alias peek_time is peek[queue_t return time];

  procedure push (
    queue : queue_t;
    variable value : inout integer_vector_ptr_t
  );

  impure function pop (
    queue : queue_t
  ) return integer_vector_ptr_t;

  procedure peek (
    queue : queue_t;
    variable value : out integer_vector_ptr_t;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return integer_vector_ptr_t;

  alias push_integer_vector_ptr_ref is push[queue_t, integer_vector_ptr_t];
  alias pop_integer_vector_ptr_ref is pop[queue_t return integer_vector_ptr_t];
  alias peek_integer_vector_ptr_ref is peek[queue_t, integer_vector_ptr_t, natural];
  alias peek_integer_vector_ptr_ref is peek[queue_t return integer_vector_ptr_t];

  procedure push (
    queue : queue_t;
    variable value : inout string_ptr_t
  );

  impure function pop (
    queue : queue_t
  ) return string_ptr_t;

  procedure peek (
    queue : queue_t;
    variable value : out string_ptr_t;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return string_ptr_t;

  alias push_string_ptr_ref is push[queue_t, string_ptr_t];
  alias pop_string_ptr_ref is pop[queue_t return string_ptr_t];
  alias peek_string_ptr_ref is peek[queue_t, string_ptr_t, natural];
  alias peek_string_ptr_ref is peek[queue_t return string_ptr_t];

  procedure push (
    queue : queue_t;
    variable value : inout queue_t
  );

  impure function pop (
    queue : queue_t
  ) return queue_t;

  procedure peek (
    queue : queue_t;
    variable value : out queue_t;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return queue_t;

  alias push_queue_ref is push[queue_t, queue_t];
  alias pop_queue_ref is pop[queue_t return queue_t];
  alias peek_queue_ref is peek[queue_t, queue_t, natural];
  alias peek_queue_ref is peek[queue_t return queue_t];

  procedure push_ref (
    constant queue : queue_t;
    value : inout integer_array_t
  );

  impure function pop_ref (
    queue : queue_t
  ) return integer_array_t;

  procedure peek_ref (
    queue : queue_t;
    variable value : out integer_array_t;
    variable offset : inout natural
  );

  impure function peek_ref (
    queue : queue_t
  ) return integer_array_t;

  alias push_integer_array_t_ref is push_ref[queue_t, integer_array_t];
  alias pop_integer_array_t_ref is pop_ref[queue_t return integer_array_t];
  alias peek_integer_array_t_ref is peek_ref[queue_t, integer_array_t, natural];
  alias peek_integer_array_t_ref is peek_ref[queue_t return integer_array_t];

  -- Private
  type queue_element_type_t is (
    vhdl_character, vhdl_integer, vunit_byte, vhdl_string, vhdl_boolean, vhdl_real, vhdl_bit, ieee_std_ulogic,
    vhdl_severity_level, vhdl_file_open_status, vhdl_file_open_kind, vhdl_bit_vector, vhdl_std_ulogic_vector,
    ieee_complex, ieee_complex_polar, ieee_numeric_bit_unsigned, ieee_numeric_bit_signed,
    ieee_numeric_std_unsigned, ieee_numeric_std_signed, vhdl_time, vunit_integer_vector_ptr_t,
    vunit_string_ptr_t, vunit_queue_t, vunit_integer_array_t, vhdl_boolean_vector, vhdl_integer_vector,
    vhdl_real_vector, vhdl_time_vector, ieee_ufixed, ieee_sfixed, ieee_float
  );
  constant queue_element_type_t_code_length : positive := 1;

  function encode (
    data : queue_t
  ) return string;

  function decode (
    code : string
  ) return queue_t;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out queue_t
  );

  alias encode_queue_t is encode[queue_t return string];
  alias decode_queue_t is decode[string return queue_t];

  procedure push_type (
    queue        : queue_t;
    element_type : queue_element_type_t
  );

  procedure check_type_pop (
    queue        : queue_t;
    element_type : queue_element_type_t
  );
  alias check_type is check_type_pop[queue_t, queue_element_type_t];

  procedure check_type_peek (
    queue        : queue_t;
    element_type : queue_element_type_t;
    variable offset : inout natural
  );

  procedure unsafe_push (
    queue : queue_t;
    value : character
  );

  impure function unsafe_pop (
    queue : queue_t
  ) return character;

  procedure unsafe_peek (
    queue : queue_t;
    variable value : out character;
    variable offset : inout natural
  );

  impure function unsafe_peek (
    queue : queue_t
  ) return character;

  procedure push_variable_string (
    queue : queue_t;
    value : string
  );

  impure function pop_variable_string (
    queue : queue_t
  ) return string;

  procedure peek_variable_string (
    queue : queue_t;
    variable value : out string;
    variable offset : inout natural
  );

  impure function peek_variable_string (
    queue : queue_t;
    offset : natural := 0
  ) return string;

  procedure push_fix_string (
    queue : queue_t;
    value : string
  );

  impure function pop_fix_string (
    queue  : queue_t;
    length : natural
  ) return string;

  procedure peek_fix_string (
    queue  : queue_t;
    variable result : out string;
    variable offset : inout natural
  );

  impure function peek_fix_string (
    queue  : queue_t;
    length : natural;
    offset : natural := 0
  ) return string;
end package;
