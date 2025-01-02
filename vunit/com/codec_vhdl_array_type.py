# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
                init_value = ""
                definitions += template.unconstrained_1d_array_definition.substitute(
                    array_type=self.identifier,
                    init_value=init_value,
                    range_type=self.range1.range_type,
                )
                definitions += template.unconstrained_1d_array_to_string_definition.substitute(
                    array_type=self.identifier, range_type=self.range1.range_type
                )
            else:
                definitions += template.unconstrained_2d_array_definition.substitute(
                    array_type=self.identifier,
                    range_type1=self.range1.range_type,
                    range_type2=self.range2.range_type,
                )
                definitions += template.unconstrained_2d_array_to_string_definition.substitute(
                    array_type=self.identifier,
                    range_type1=self.range1.range_type,
                    range_type2=self.range2.range_type,
                )

        return declarations, definitions


class ArrayCodecTemplate(DatatypeCodecTemplate):
    """This class contains array codec templates."""

    constrained_1d_array_to_string_definition = Template(
        """\
  function to_string (
    constant data : $type)
    return string is
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
  end function to_string;

"""
    )

    constrained_2d_array_to_string_definition = Template(
        """\
  function to_string (
    constant data : $type)
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
  end function to_string;

"""
    )

    unconstrained_1d_array_to_string_definition = Template(
        """\
  function to_string (
    constant data : $array_type)
    return string is
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
  end function to_string;

"""
    )

    unconstrained_2d_array_to_string_definition = Template(
        """\
  function to_string (
    constant data : $array_type)
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

    return create_array_group(element(1 to length), encode(data'left(1)), encode(data'right(1)), data'ascending(1),
                              encode(data'left(2)), encode(data'right(2)), data'ascending(2));
  end function to_string;

"""
    )

    constrained_1d_array_definition = Template(
        """\
  function encode (
    constant data : $type)
    return string is
    constant length : positive := get_encoded_length(encode(data(data'left)));
    variable index : positive := 1;
    variable ret_val : string(1 to data'length * length);
  begin
    for i in data'range loop
      ret_val(index to index + length - 1) := encode(data(i));
      index := index + length;
    end loop;

    return ret_val;
  end function encode;

  procedure decode (
    constant code   : string;
    variable index : inout   positive;
    variable result : out $type) is
  begin
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end procedure decode;

  function decode (
    constant code : string)
    return $type is
    variable ret_val : $type;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end function decode;

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
  function encode (
    constant data : $type)
    return string is
    constant length : positive := get_encoded_length(encode(data(data'left(1), data'left(2))));
    variable index : positive := 1;
    variable ret_val : string(1 to data'length(1) * data'length(2) * length);
  begin
    for i in data'range(1) loop
      for j in data'range(2) loop
        ret_val(index to index + length - 1) := encode(data(i,j));
        index := index + length;
      end loop;
    end loop;

    return ret_val;
  end function encode;

  procedure decode (
    constant code   : string;
    variable index : inout   positive;
    variable result : out $type) is
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        decode(code, index, result(i,j));
      end loop;
    end loop;
  end procedure decode;

  function decode (
    constant code : string)
    return $type is
    variable ret_val : $type;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end function decode;

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

    unconstrained_1d_array_definition = Template(
        """\
  function encode (
    constant data : $array_type)
    return string is
    function element_length (
      constant data : $array_type)
      return natural is
    begin
      if data'length = 0 then
        return 0;
      else
        return get_encoded_length(encode(data(data'left)));
      end if;
    end;
    constant length : natural := element_length(data);
    constant range_length : positive := get_encoded_length(encode(data'left));
    variable index : positive := 2 + 2 * range_length;
    variable ret_val : string(1 to 1 + 2 * range_length + data'length * length);
  begin
    ret_val(1 to 1 + 2 * range_length) := encode_array_header(encode(data'left),
                                                              encode(data'right),
                                                              encode(data'ascending));
    for i in data'range loop
      ret_val(index to index + length - 1) := encode(data(i));
      index := index + length;
    end loop;

    return ret_val;
  end function encode;

  procedure decode (
    constant code   : string;
    variable index : inout   positive;
    variable result : out $array_type) is
    constant range_length : positive := get_encoded_length(encode($range_type'left));
  begin
    index := index + 1 + 2 * range_length;
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end procedure decode;

  function decode (
    constant code : string)
    return $array_type is
    constant range_length : positive := get_encoded_length(encode($range_type'left));
    function ret_val_range (
      constant code : string)
      return $array_type is
      constant range_left : $range_type := decode(code(code'left to code'left + range_length - 1));
      constant range_right : $range_type := decode(code(code'left + range_length to code'left + 2 * range_length - 1));
      constant is_ascending : boolean := decode(code(code'left + 2 * range_length to code'left + 2 *range_length));
      variable ret_val_ascending : $array_type(range_left to range_right);
      variable ret_val_descending : $array_type(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else
        return ret_val_descending;
      end if;
    end function ret_val_range;
    constant array_of_correct_range : $array_type := ret_val_range(code);
    variable ret_val : $array_type(array_of_correct_range'range)$init_value;
    variable index : positive := code'left + 1 + 2 * range_length;
  begin
    for i in ret_val'range loop
      decode(code, index, ret_val(i));
    end loop;

    return ret_val;
  end function decode;

  procedure push(queue : queue_t; value : $array_type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $array_type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $array_type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $array_type is
  begin
    return pop(msg.data);
  end;

"""
    )

    unconstrained_2d_array_definition = Template(
        """\
  function encode (
    constant data : $array_type)
    return string is
    function element_length (
      constant data : $array_type)
      return natural is
    begin
      if data'length(1) * data'length(2) = 0 then
        return 0;
      else
        return get_encoded_length(encode(data(data'left(1), data'left(2))));
      end if;
    end;
    constant length : natural := element_length(data);
    constant range1_length : positive := get_encoded_length(encode(data'left(1)));
    constant range2_length : positive := get_encoded_length(encode(data'left(2)));
    variable index : positive := 3 + 2 * range1_length + 2 * range2_length;
    variable ret_val : string(1 to 2 + 2 * range1_length + 2 * range2_length +
                                   data'length(1) * data'length(2) * length);
  begin
    ret_val(1 to 2 + 2 * range1_length + 2 * range2_length) :=
      encode_array_header(encode(data'left(1)), encode(data'right(1)), encode(data'ascending(1)),
                          encode(data'left(2)), encode(data'right(2)), encode(data'ascending(2)));
    for i in data'range(1) loop
      for j in data'range(2) loop
        ret_val(index to index + length - 1) := encode(data(i,j));
        index := index + length;
      end loop;
    end loop;

    return ret_val;
  end function encode;

  procedure decode (
    constant code   : string;
    variable index : inout   positive;
    variable result : out $array_type) is
    constant range1_length : positive := get_encoded_length(encode($range_type1'left));
    constant range2_length : positive := get_encoded_length(encode($range_type2'left));
  begin
    index := index + 2 + 2 * range1_length + 2 * range2_length;
    for i in result'range(1) loop
      for j in result'range(2) loop
        decode(code, index, result(i,j));
      end loop;
    end loop;
  end procedure decode;

  function decode (
    constant code : string)
    return $array_type is
    constant range1_length : positive := get_encoded_length(encode($range_type1'left));
    constant range2_length : positive := get_encoded_length(encode($range_type2'left));
    function ret_val_range (
      constant code : string)
      return $array_type is
      constant range_left1 : $range_type1 := decode(code(code'left to code'left + range1_length - 1));
      constant range_right1 : $range_type1 := decode(code(code'left + range1_length to
                                                          code'left + 2 * range1_length - 1));
      constant is_ascending1 : boolean := decode(code(code'left + 2 * range1_length to
                                                      code'left + 2 * range1_length));
      constant range_left2 : $range_type2 := decode(code(code'left + 2 * range1_length + 1 to
                                                         code'left + 2 * range1_length + range2_length));
      constant range_right2 : $range_type2 := decode(code(code'left + 2 * range1_length + range2_length + 1 to
                                                          code'left + 2 * range1_length + 2 * range2_length));
      constant is_ascending2 : boolean := decode(code(code'left + 2 * range1_length + 2 * range2_length + 1 to
                                                      code'left + 2 * range1_length + 2 * range2_length + 1));
      variable ret_val_ascending_ascending : $array_type(range_left1 to range_right1,
                                                         range_left2 to range_right2);
      variable ret_val_ascending_decending : $array_type(range_left1 to range_right1,
                                                         range_left2 downto range_right2);
      variable ret_val_decending_ascending : $array_type(range_left1 downto range_right1,
                                                         range_left2 to range_right2);
      variable ret_val_decending_decending : $array_type(range_left1 downto range_right1,
                                                         range_left2 downto range_right2);
    begin
      if is_ascending1 then
        if is_ascending2 then
          return ret_val_ascending_ascending;
        else
          return ret_val_ascending_decending;
        end if;
      else
        if is_ascending2 then
          return ret_val_decending_ascending;
        else
          return ret_val_decending_decending;
        end if;
      end if;
    end function ret_val_range;

    constant array_of_correct_range : $array_type := ret_val_range(code);
    variable ret_val : $array_type(array_of_correct_range'range(1), array_of_correct_range'range(2));
    variable index : positive := code'left + 2 + 2 * range1_length + 2 * range2_length;
  begin
    for i in ret_val'range(1) loop
      for j in ret_val'range(2) loop
        decode(code, index, ret_val(i,j));
      end loop;
    end loop;

    return ret_val;
  end function decode;

  procedure push(queue : queue_t; value : $array_type) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $array_type is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(msg : msg_t; value : $array_type) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return $array_type is
  begin
    return pop(msg.data);
  end;

"""
    )
