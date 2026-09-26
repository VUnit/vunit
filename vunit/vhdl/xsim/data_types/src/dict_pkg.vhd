-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- dict_pkg provides the dict_t data type which is an dynamic dictionary implementation.
-- All dict keys are strings but the values can be of many different data types and a single
-- dict can hold a mix of data types.

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;

use work.codec_pkg.all;
use work.data_types_private_pkg.all;
use work.integer_array_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.queue_pkg.all;
use work.string_ptr_pkg.all;
use work.string_ptr_pool_pkg.all;

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
  -- There are also overloaded get and set subprogram aliases for each type. These comes
  -- with the risk of ambiguities which the type specific subprograms don't have.
  procedure set_string (
    dict       : dict_t;
    key        : string;
    value      : string
  );

  impure function get_string (
    dict : dict_t;
    key  : string
  ) return string;

  procedure set_integer (
    dict       : dict_t;
    key        : string;
    value      : integer
  );

  impure function get_integer (
    dict : dict_t;
    key  : string
  ) return integer;

  procedure set_character (
    dict       : dict_t;
    key        : string;
    value      : character
  );

  impure function get_character (
    dict : dict_t;
    key  : string
  ) return character;

  procedure set_boolean (
    dict       : dict_t;
    key        : string;
    value      : boolean
  );

  impure function get_boolean (
    dict : dict_t;
    key  : string
  ) return boolean;

  procedure set_real (
    dict       : dict_t;
    key        : string;
    value      : real
  );

  impure function get_real (
    dict : dict_t;
    key  : string
  ) return real;

  procedure set_bit (
    dict       : dict_t;
    key        : string;
    value      : bit
  );

  impure function get_bit (
    dict : dict_t;
    key  : string
  ) return bit;

  procedure set_std_ulogic (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic
  );

  impure function get_std_ulogic (
    dict : dict_t;
    key  : string
  ) return std_ulogic;

  procedure set_severity_level (
    dict       : dict_t;
    key        : string;
    value      : severity_level
  );

  impure function get_severity_level (
    dict : dict_t;
    key  : string
  ) return severity_level;

  procedure set_file_open_status (
    dict       : dict_t;
    key        : string;
    value      : file_open_status
  );

  impure function get_file_open_status (
    dict : dict_t;
    key  : string
  ) return file_open_status;

  procedure set_file_open_kind (
    dict       : dict_t;
    key        : string;
    value      : file_open_kind
  );

  impure function get_file_open_kind (
    dict : dict_t;
    key  : string
  ) return file_open_kind;

  procedure set_bit_vector (
    dict       : dict_t;
    key        : string;
    value      : bit_vector
  );

  impure function get_bit_vector (
    dict : dict_t;
    key  : string
  ) return bit_vector;

  procedure set_std_ulogic_vector (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic_vector
  );

  impure function get_std_ulogic_vector (
    dict : dict_t;
    key  : string
  ) return std_ulogic_vector;

  procedure set_complex (
    dict       : dict_t;
    key        : string;
    value      : complex
  );

  impure function get_complex (
    dict : dict_t;
    key  : string
  ) return complex;

  procedure set_complex_polar (
    dict       : dict_t;
    key        : string;
    value      : complex_polar
  );

  impure function get_complex_polar (
    dict : dict_t;
    key  : string
  ) return complex_polar;

  procedure set_numeric_bit_unsigned (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.unsigned
  );

  impure function get_numeric_bit_unsigned (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.unsigned;

  procedure set_numeric_bit_signed (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.signed
  );

  impure function get_numeric_bit_signed (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.signed;

  procedure set_numeric_std_unsigned (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.unsigned
  );

  impure function get_numeric_std_unsigned (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.unsigned;

  procedure set_numeric_std_signed (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.signed
  );

  impure function get_numeric_std_signed (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.signed;

  procedure set_time (
    dict       : dict_t;
    key        : string;
    value      : time
  );

  impure function get_time (
    dict : dict_t;
    key  : string
  ) return time;

  -- get and set aliases for every type specific get and set subprogram. All but the set
  -- and get aliases for string type values will be enabled in VUnit v5.0. These create
  -- ambiguities with the original set and get subprograms for string and a backward
  -- compatibility that needs to be solved in a major VUnit release

  alias set is set_string[dict_t, string, string];
  alias get is get_string[dict_t, string return string];
--  alias set is set_integer[dict_t, string, integer];
--  alias get is get_integer[dict_t, string return integer];
--  alias set is set_character[dict_t, string, character];
--  alias get is get_character[dict_t, string return character];
--  alias set is set_boolean[dict_t, string, boolean];
--  alias get is get_boolean[dict_t, string return boolean];
--  alias set is set_real[dict_t, string, real];
--  alias get is get_real[dict_t, string return real];
--  alias set is set_bit[dict_t, string, bit];
--  alias get is get_bit[dict_t, string return bit];
--  alias set is set_std_ulogic[dict_t, string, std_ulogic];
--  alias get is get_std_ulogic[dict_t, string return std_ulogic];
--  alias set is set_severity_level[dict_t, string, severity_level];
--  alias get is get_severity_level[dict_t, string return severity_level];
--  alias set is set_file_open_status[dict_t, string, file_open_status];
--  alias get is get_file_open_status[dict_t, string return file_open_status];
--  alias set is set_file_open_kind[dict_t, string, file_open_kind];
--  alias get is get_file_open_kind[dict_t, string return file_open_kind];
--  alias set is set_bit_vector[dict_t, string, bit_vector];
--  alias get is get_bit_vector[dict_t, string return bit_vector];
--  alias set is set_std_ulogic_vector[dict_t, string, std_ulogic_vector];
--  alias get is get_std_ulogic_vector[dict_t, string return std_ulogic_vector];
--  alias set is set_complex[dict_t, string, complex];
--  alias get is get_complex[dict_t, string return complex];
--  alias set is set_complex_polar[dict_t, string, complex_polar];
--  alias get is get_complex_polar[dict_t, string return complex_polar];
--  alias set is set_numeric_bit_unsigned[dict_t, string, ieee.numeric_bit.unsigned];
--  alias get is get_numeric_bit_unsigned[dict_t, string return ieee.numeric_bit.unsigned];
--  alias set is set_numeric_bit_signed[dict_t, string, ieee.numeric_bit.signed];
--  alias get is get_numeric_bit_signed[dict_t, string return ieee.numeric_bit.signed];
--  alias set is set_numeric_std_unsigned[dict_t, string, ieee.numeric_std.unsigned];
--  alias get is get_numeric_std_unsigned[dict_t, string return ieee.numeric_std.unsigned];
--  alias set is set_numeric_std_signed[dict_t, string, ieee.numeric_std.signed];
--  alias get is get_numeric_std_signed[dict_t, string return ieee.numeric_std.signed];
--  alias set is set_time[dict_t, string, time];
--  alias get is get_time[dict_t, string return time];
--  alias set is set_boolean_vector[dict_t, string, boolean_vector];
--  alias get is get_boolean_vector[dict_t, string return boolean_vector];
--  alias set is set_time_vector[dict_t, string, time_vector];
--  alias get is get_time_vector[dict_t, string return time_vector];
--  alias set is set_real_vector[dict_t, string, real_vector];
--  alias get is get_real_vector[dict_t, string return real_vector];
--  alias set is set_integer_vector[dict_t, string, integer_vector];
--  alias get is get_integer_vector[dict_t, string return integer_vector];
--  alias set is set_ufixed[dict_t, string, ufixed];
--  alias get is get_ufixed[dict_t, string return ufixed];
--  alias set is set_sfixed[dict_t, string, sfixed];
--  alias get is get_sfixed[dict_t, string return sfixed];
--  alias set is set_float[dict_t, string, float];
--  alias get is get_float[dict_t, string return float];

  -- Setting a dict value that is of a VUnit reference data type will hand over the
  -- ownership of the reference to the dict, i.e. the value in the set call will be
  -- null when the procedure returns. The strict handling of ownership reduces the
  -- risk of bugs caused by several variables referencing and modifying the same piece
  -- of data. If that is the intention the value has to be copied before passing it to
  -- the set procedure. The set procedures has a "_ref" suffix to highlight this difference
  -- in behaviour.
  procedure set_dict_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout dict_t
  );

  impure function get_dict_t_ref (
    dict : dict_t;
    key  : string
  ) return dict_t;

  procedure set_integer_vector_ptr_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_vector_ptr_t
  );

  impure function get_integer_vector_ptr_t_ref (
    dict : dict_t;
    key  : string
  ) return integer_vector_ptr_t;

  procedure set_string_ptr_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout string_ptr_t
  );

  impure function get_string_ptr_t_ref (
    dict : dict_t;
    key  : string
  ) return string_ptr_t;

  procedure set_integer_array_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_array_t
  );

  impure function get_integer_array_t_ref (
    dict : dict_t;
    key  : string
  ) return integer_array_t;

  procedure set_queue_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout queue_t
  );

  impure function get_queue_t_ref (
    dict : dict_t;
    key  : string
  ) return queue_t;

  alias set_ref is set_dict_t_ref[dict_t, string, dict_t];
  alias get_ref is get_dict_t_ref[dict_t, string return dict_t];
  alias set_ref is set_integer_vector_ptr_t_ref[dict_t, string, integer_vector_ptr_t];
  alias get_ref is get_integer_vector_ptr_t_ref[dict_t, string return integer_vector_ptr_t];
  alias set_ref is set_string_ptr_t_ref[dict_t, string, string_ptr_t];
  alias get_ref is get_string_ptr_t_ref[dict_t, string return string_ptr_t];
  alias set_ref is set_integer_array_t_ref[dict_t, string, integer_array_t];
  alias get_ref is get_integer_array_t_ref[dict_t, string return integer_array_t];
  alias set_ref is set_queue_t_ref[dict_t, string, queue_t];
  alias get_ref is get_queue_t_ref[dict_t, string return queue_t];

  procedure push_ref (
    constant queue : queue_t;
    value : inout dict_t
  );

  impure function pop_ref (
    queue : queue_t
  ) return dict_t;

  alias push_dict_t_ref is push_ref[queue_t, dict_t];
  alias pop_dict_t_ref is pop_ref[queue_t return dict_t];

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
