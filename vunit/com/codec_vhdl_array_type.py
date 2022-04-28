# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Module containing the CodecVHDLArrayType class.
"""
from string import Template
from vunit.vhdl_parser import VHDLArrayType
from vunit.com.codec_datatype_template import DatatypeCodecTemplate


class CodecVHDLArrayType(VHDLArrayType):
    """Class derived from VHDLArrayType to provide codec generator functionality constrained and
    unconstrained 1D/2D arrays"""

    def generate_codecs_and_support_functions(self):
        """Generate codecs and communication support functions for the array type."""
        template = ArrayCodecTemplate()

        declarations = ""
        definitions = ""
        has_one_dimension = (
            self.range2.left is None
            and self.range2.right is None
            and self.range2.attribute is None
            and self.range2.range_type is None
        )
        is_constrained = self.range1.range_type is None and self.range2.range_type is None

        declarations += template.codec_length_declarations.substitute(type=self.identifier)
        declarations += template.codec_declarations.substitute(type=self.identifier)
        declarations += template.to_string_declarations.substitute(type=self.identifier)
        if is_constrained:
            if has_one_dimension:
                definitions += template.constrained_1d_array_definition.substitute(type=self.identifier)
                definitions += template.constrained_1d_array_to_string_definition.substitute(type=self.identifier)
            else:
                definitions += template.constrained_2d_array_definition.substitute(type=self.identifier)
                definitions += template.constrained_2d_array_to_string_definition.substitute(type=self.identifier)
        else:
            if has_one_dimension:
                definitions += template.range_encoding_definition.substitute(
                    i = "",
                    type=self.identifier,
                    range_type=self.range1.range_type,
                )
                definitions += template.unconstrained_1d_array_definition.substitute(
                    type=self.identifier,
                    range_type=self.range1.range_type,
                )
                definitions += template.unconstrained_1d_array_to_string_definition.substitute(type=self.identifier)
            else:
                definitions += template.range_encoding_definition.substitute(
                    i = "1",
                    type=self.identifier,
                    range_type=self.range1.range_type,
                )
                definitions += template.range_encoding_definition.substitute(
                    i = "2",
                    type=self.identifier,
                    range_type=self.range2.range_type,
                )
                definitions += template.unconstrained_2d_array_definition.substitute(
                    type=self.identifier,
                    range_type1=self.range1.range_type,
                    range_type2=self.range2.range_type,
                )
                definitions += template.unconstrained_2d_array_to_string_definition.substitute(type=self.identifier)

        return declarations, definitions


class ArrayCodecTemplate(DatatypeCodecTemplate):
    """This class contains array codec templates."""

    codec_length_declarations = Template(
        """\
  -- Codec package extension for the type $type

  function code_length_$type(data : $type) return natural;
  alias code_length is code_length_$type[$type return natural];
"""
    )

    constrained_1d_array_to_string_definition = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type) return string is
    variable element : string(1 to 2 + data'length * 32);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);
    return element(1 to length);
  end function;

"""
    )

    constrained_2d_array_to_string_definition = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type)
    return string is
    variable element : string(1 to 2 + data'length(1) * data'length(2) * 32);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range(1) loop
      for j in data'range(2) loop
        append_group(l, encode(data(i,j)));
      end loop;
    end loop;
    close_group(l, element, length);
    return element(1 to length);
  end function;

"""
    )

    unconstrained_1d_array_to_string_definition = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type) return string is
    variable element : string(1 to 2 + data'length * 32);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);
    return create_array_group(element(1 to length), encode(data'left), encode(data'right), data'ascending);
  end function;

"""
    )

    unconstrained_2d_array_to_string_definition = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type)
    return string is
    variable element : string(1 to 2 + data'length(1) * data'length(2) * 32);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range(1) loop
      for j in data'range(2) loop
        append_group(l, encode(data(i,j)));
      end loop;
    end loop;
    close_group(l, element, length);
    return create_array_group(
      element(1 to length),
      encode(data'left(1)),
      encode(data'right(1)),
      data'ascending(1),
      encode(data'left(2)),
      encode(data'right(2)),
      data'ascending(2)
    );
  end function;

"""
    )

    constrained_1d_array_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  function code_length_$type(data : $type) return natural is
  begin
    if data'length = 0 then
      return 0;
    else
      return code_length(data(data'left)) * data'length;
    end if;
  end function;

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    for i in data'range loop
      encode(data(i), index, code);
    end loop;
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end procedure;

  function encode_$type(data : $type) return code_t is
    variable ret_val : code_t(1 to code_length_$type(data));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_$type(data, index, ret_val);
    return ret_val;
  end function;

  function decode_$type(code : code_t) return $type is
    variable ret_val : $type;
    variable index   : code_index_t := code'left;
  begin
    decode_$type(code, index, ret_val);
    return ret_val;
  end function;


  -----------------------------------------------------------------------------
  -- Queue package extension for the type $type
  -----------------------------------------------------------------------------

  procedure push(queue : queue_t; value : $type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $type is
  begin
    return pop(msg.data);
  end;

"""
    )

    constrained_2d_array_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  function code_length_$type(data : $type) return natural is
  begin
    if data'length(1) = 0 or data'length(2) = 0 then
      return 0;
    else
      return code_length(data(data'left(1), data'left(2))) * data'length(1) * data'length(2);
    end if;
  end function;

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    for i in data'range(1) loop
      for j in data'range(2) loop
        encode(data(i,j), index, code);
      end loop;
    end loop;
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        decode(code, index, result(i,j));
      end loop;
    end loop;
  end procedure;

  function encode_$type(data : $type) return code_t is
    variable ret_val : code_t(1 to code_length_$type(data));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_$type(data, index, ret_val);
    return ret_val;
  end function;

  function decode_$type(code : code_t) return $type is
    variable ret_val : $type;
    variable index   : code_index_t := code'left;
  begin
    decode_$type(code, index, ret_val);
    return ret_val;
  end function;


  -----------------------------------------------------------------------------
  -- Queue package extension for the type $type
  -----------------------------------------------------------------------------

  procedure push(queue : queue_t; value : $type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $type is
  begin
    return pop(msg.data);
  end;

"""
    )

    # Constrained and unconstrained array are dealt the same way
    range_encoding_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type: definition of the range encode/decode
  -----------------------------------------------------------------------------

  -- Type only used to ccarry the range information
  type range${i}_${type}_t is array($range_type range <>) of bit;

  function code_length_range${i}_$type(data : $range_type := $range_type'left) return natural is
  begin
    -- We need to encode the left and right bounds and the ascending information
    return 2 * code_length(data) + code_length_boolean;
  end function;

  procedure encode_range${i}_$type(
    constant range_left : $range_type;
    constant range_right : $range_type;
    constant is_ascending : boolean;
    variable index : inout code_index_t;
    variable code : inout code_t
  ) is
  begin
    encode(range_left, index, code);
    encode(range_right, index, code);
    encode_boolean(is_ascending, index, code);
  end procedure;

  function decode_range${i}_$type(code : code_t; index : code_index_t) return range${i}_${type}_t is
    variable code_alias : code_t(1 to code'length-index+1) := code(index to code'length);
    constant range_left : $range_type := decode(
      code_alias(1 to code_length($range_type'left))
    );
    constant range_right : $range_type := decode(
      code_alias(1 + code_length($range_type'left) to code_length($range_type'left)*2)
    );
    constant is_ascending : boolean := decode_boolean(
      code_alias(1 + code_length($range_type'left)*2 to code_length($range_type'left)*2 + code_length_boolean)
    );
    variable ret_val_ascending  : range${i}_${type}_t(range_left to range_right);
    variable ret_val_descending : range${i}_${type}_t(range_left downto range_right);
  begin
    if is_ascending then
      return ret_val_ascending;
    else
      return ret_val_descending;
    end if;
  end function;

"""
    )

    # Constrained and unconstrained array are dealt the same way
    unconstrained_1d_array_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  function code_length_$type(data : $type) return natural is
  begin
    if data'length = 0 then
      return code_length_range_$type;
    else
      return code_length_range_$type + code_length(data(data'left)) * data'length;
    end if;
  end function;

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    encode_range_$type(data'left, data'right, data'ascending, index, code);
    for i in data'range loop
      encode(data(i), index, code);
    end loop;
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    index := index + code_length_range_$type;
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end procedure;

  function encode_$type(data : $type) return code_t is
    variable ret_val : code_t(1 to code_length_$type(data));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_$type(data, index, ret_val);
    return ret_val;
  end function;

  function decode_$type(code : code_t) return $type is
    constant ret_range : range_${type}_t := decode_range_$type(code, code'left);
    variable ret_val   : $type(ret_range'range);
    variable index     : code_index_t := code'left;
  begin
    decode_$type(code, index, ret_val);
    return ret_val;
  end function;


  -----------------------------------------------------------------------------
  -- Queue package extension for the type $type
  -----------------------------------------------------------------------------

  procedure push(queue : queue_t; value : $type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $type is
  begin
    return pop(msg.data);
  end;

"""
    )

    unconstrained_2d_array_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  function code_length_$type(data : $type) return natural is
  begin
    if data'length(1) = 0 or data'length(2) = 0 then
      return code_length_range1_$type + code_length_range2_$type;
    else
      return code_length_range1_$type + code_length_range2_$type + code_length(data(data'left(1), data'left(2))) * data'length(1) * data'length(2);
    end if;
  end function;

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    encode_range1_$type(data'left(1), data'right(1), data'ascending(1), index, code);
    encode_range2_$type(data'left(2), data'right(2), data'ascending(2), index, code);
    for i in data'range(1) loop
      for j in data'range(2) loop
        encode(data(i,j), index, code);
      end loop;
    end loop;
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    index := index + code_length_range1_$type + code_length_range2_$type;
    for i in result'range(1) loop
      for j in result'range(2) loop
        decode(code, index, result(i,j));
      end loop;
    end loop;
  end procedure;

  function encode_$type(data : $type) return code_t is
    variable ret_val : code_t(1 to code_length_$type(data));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_$type(data, index, ret_val);
    return ret_val;
  end function;

  function decode_$type(code : code_t) return $type is
    constant ret_range1 : range1_${type}_t := decode_range1_$type(code, code'left);
    constant ret_range2 : range2_${type}_t := decode_range2_$type(code, code'left + code_length_range1_$type);
    variable ret_val    : $type(ret_range1'range, ret_range2'range);
    variable index      : code_index_t := code'left;
  begin
    decode_$type(code, index, ret_val);
    return ret_val;
  end function;


  -----------------------------------------------------------------------------
  -- Queue package extension for the type $type
  -----------------------------------------------------------------------------

  procedure push(queue : queue_t; value : $type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $type is
  begin
    return pop(msg.data);
  end;

"""
    )
