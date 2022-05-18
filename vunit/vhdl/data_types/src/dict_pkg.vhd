-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- dict_pkg provides the dict_t data type which is an dynamic dictionary implementation.
-- All dict keys are strings but the values can be of many different data types and a single
-- dict can hold a mix of data types.

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;

use work.string_ptr_pkg.all;
use work.string_ptr_pool_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.codec_pkg.all;
use work.data_types_private_pkg.all;
use work.queue_pkg.all;
use work.integer_array_pkg.all;
use work.byte_vector_ptr_pkg.all;

package dict_pkg is
  type dict_t is record
    p_meta               : integer_vector_ptr_t;
    p_bucket_lengths     : integer_vector_ptr_t;
    p_bucket_keys        : integer_vector_ptr_t;
    p_bucket_values      : integer_vector_ptr_t;
    p_bucket_value_types : integer_vector_ptr_t;
  end record;
  constant null_dict : dict_t := (others => null_ptr);

  -- Create a new empty dict. Must be done before applying any other operation on the dict.
  impure function new_dict
  return dict_t;

  procedure deallocate (
    variable dict : inout dict_t
  );

  impure function has_key (
    dict : dict_t;
    key  : string
  ) return boolean;

  impure function num_keys (
    dict : dict_t
  ) return natural;

  procedure remove (
    dict : dict_t;
    key  : string
  );

  -- Set and get for different value data types. A dict can hold any mix of data types.
  -- Each overloaded get and set subprogram also has a type specific alias, for
  -- example get_integer. These are used to resolve ambiguities when the compiler
  -- can't determine which overloaded subprogram that is intended.
  procedure set (
    dict       : dict_t;
    key        : string;
    value      : integer
  );
  alias set_integer is set[dict_t, string, integer];

  impure function get (
    dict : dict_t;
    key  : string
  ) return integer;
  alias get_integer is get[dict_t, string return integer];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : character
  );
  alias set_character is set[dict_t, string, character];

  impure function get (
    dict : dict_t;
    key  : string
  ) return character;
  alias get_character is get[dict_t, string return character];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : boolean
  );
  alias set_boolean is set[dict_t, string, boolean];

  impure function get (
    dict : dict_t;
    key  : string
  ) return boolean;
  alias get_boolean is get[dict_t, string return boolean];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : real
  );
  alias set_real is set[dict_t, string, real];

  impure function get (
    dict : dict_t;
    key  : string
  ) return real;
  alias get_real is get[dict_t, string return real];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : bit
  );
  alias set_bit is set[dict_t, string, bit];

  impure function get (
    dict : dict_t;
    key  : string
  ) return bit;
  alias get_bit is get[dict_t, string return bit];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic
  );
  alias set_std_ulogic is set[dict_t, string, std_ulogic];

  impure function get (
    dict : dict_t;
    key  : string
  ) return std_ulogic;
  alias get_std_ulogic is get[dict_t, string return std_ulogic];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : severity_level
  );
  alias set_severity_level is set[dict_t, string, severity_level];

  impure function get (
    dict : dict_t;
    key  : string
  ) return severity_level;
  alias get_severity_level is get[dict_t, string return severity_level];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : file_open_status
  );
  alias set_file_open_status is set[dict_t, string, file_open_status];

  impure function get (
    dict : dict_t;
    key  : string
  ) return file_open_status;
  alias get_file_open_status is get[dict_t, string return file_open_status];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : file_open_kind
  );
  alias set_file_open_kind is set[dict_t, string, file_open_kind];

  impure function get (
    dict : dict_t;
    key  : string
  ) return file_open_kind;
  alias get_file_open_kind is get[dict_t, string return file_open_kind];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : bit_vector
  );
  alias set_bit_vector is set[dict_t, string, bit_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return bit_vector;
  alias get_bit_vector is get[dict_t, string return bit_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic_vector
  );
  alias set_std_ulogic_vector is set[dict_t, string, std_ulogic_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return std_ulogic_vector;
  alias get_std_ulogic_vector is get[dict_t, string return std_ulogic_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : complex
  );
  alias set_complex is set[dict_t, string, complex];

  impure function get (
    dict : dict_t;
    key  : string
  ) return complex;
  alias get_complex is get[dict_t, string return complex];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : complex_polar
  );
  alias set_complex_polar is set[dict_t, string, complex_polar];

  impure function get (
    dict : dict_t;
    key  : string
  ) return complex_polar;
  alias get_complex_polar is get[dict_t, string return complex_polar];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.unsigned
  );
  alias set_numeric_bit_unsigned is set[dict_t, string, ieee.numeric_bit.unsigned];

  impure function get (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.unsigned;
  alias get_numeric_bit_unsigned is get[dict_t, string return ieee.numeric_bit.unsigned];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.signed
  );
  alias set_numeric_bit_signed is set[dict_t, string, ieee.numeric_bit.signed];

  impure function get (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.signed;
  alias get_numeric_bit_signed is get[dict_t, string return ieee.numeric_bit.signed];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.unsigned
  );
  alias set_numeric_std_unsigned is set[dict_t, string, ieee.numeric_std.unsigned];

  impure function get (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.unsigned;
  alias get_numeric_std_unsigned is get[dict_t, string return ieee.numeric_std.unsigned];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.signed
  );
  alias set_numeric_std_signed is set[dict_t, string, ieee.numeric_std.signed];

  impure function get (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.signed;
  alias get_numeric_std_signed is get[dict_t, string return ieee.numeric_std.signed];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : string
  );
  alias set_string is set[dict_t, string, string];

  impure function get (
    dict : dict_t;
    key  : string
  ) return string;
  alias get_string is get[dict_t, string return string];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : time
  );
  alias set_time is set[dict_t, string, time];

  impure function get (
    dict : dict_t;
    key  : string
  ) return time;
  alias get_time is get[dict_t, string return time];

  procedure set_ref (
    dict       : dict_t;
    key        : string;
    value : inout dict_t
  );
  alias set_dict_t_ref is set_ref[dict_t, string, dict_t];

  impure function get_ref (
    dict : dict_t;
    key  : string
  ) return dict_t;
  alias get_dict_t_ref is get_ref[dict_t, string return dict_t];

  procedure set_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_vector_ptr_t
  );
  alias set_integer_vector_ptr_t_ref is set_ref[dict_t, string, integer_vector_ptr_t];

  impure function get_ref (
    dict : dict_t;
    key  : string
  ) return integer_vector_ptr_t;
  alias get_integer_vector_ptr_t_ref is get_ref[dict_t, string return integer_vector_ptr_t];

  procedure set_ref (
    dict       : dict_t;
    key        : string;
    value : inout string_ptr_t
  );
  alias set_string_ptr_t_ref is set_ref[dict_t, string, string_ptr_t];

  impure function get_ref (
    dict : dict_t;
    key  : string
  ) return string_ptr_t;
  alias get_string_ptr_t_ref is get_ref[dict_t, string return string_ptr_t];

  procedure set_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_array_t
  );
  alias set_integer_array_t_ref is set_ref[dict_t, string, integer_array_t];

  impure function get_ref (
    dict : dict_t;
    key  : string
  ) return integer_array_t;
  alias get_integer_array_t_ref is get_ref[dict_t, string return integer_array_t];

  procedure set_ref (
    dict       : dict_t;
    key        : string;
    value : inout queue_t
  );
  alias set_queue_t_ref is set_ref[dict_t, string, queue_t];

  impure function get_ref (
    dict : dict_t;
    key  : string
  ) return queue_t;
  alias get_queue_t_ref is get_ref[dict_t, string return queue_t];

  function encode (
    data : dict_t
  ) return string;

  function decode (
    code : string
  ) return dict_t;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out dict_t
  );

  procedure push_ref (
    constant queue : queue_t;
    value : inout dict_t
  );

  impure function pop_ref (
    queue : queue_t
  ) return dict_t;

  alias push_dict_t_ref is push_ref[queue_t, dict_t];
  alias pop_dict_t_ref is pop_ref[queue_t return dict_t];

  -- Private
  procedure p_set_with_type (
    dict       : dict_t;
    key, value : string;
    value_type : data_type_t
  );

  impure function p_get_with_type (
    dict : dict_t;
    key  : string;
    expected_value_type : data_type_t
  ) return string;
end package;
