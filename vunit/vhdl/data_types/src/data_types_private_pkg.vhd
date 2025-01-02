-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;

package data_types_private_pkg is
  type data_type_t is (
    vhdl_character, vhdl_integer, vunit_byte, vhdl_string, vhdl_boolean, vhdl_real, vhdl_bit, ieee_std_ulogic,
    vhdl_severity_level, vhdl_file_open_status, vhdl_file_open_kind, vhdl_bit_vector, ieee_std_ulogic_vector,
    ieee_complex, ieee_complex_polar, ieee_numeric_bit_unsigned, ieee_numeric_bit_signed,
    ieee_numeric_std_unsigned, ieee_numeric_std_signed, vhdl_time, vunit_integer_vector_ptr_t,
    vunit_string_ptr_t, vunit_queue_t, vunit_integer_array_t, vhdl_boolean_vector, vhdl_integer_vector,
    vhdl_real_vector, vhdl_time_vector, ieee_ufixed, ieee_sfixed, ieee_float, vunit_dict_t
  );

  impure function to_string(data_type : data_type_t) return string;
end package;

package body data_types_private_pkg is
  impure function to_string(data_type : data_type_t) return string is
    variable split_data_type : lines_t;
  begin
    split_data_type := split(data_type_t'image(data_type), "_", 1);
    return split_data_type(1).all;
  end;
end package body;
