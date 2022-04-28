# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Module containing the CodecVHDLEnumerationType class.
"""
from string import Template
from vunit.vhdl_parser import VHDLEnumerationType
from vunit.com.codec_datatype_template import DatatypeCodecTemplate


class CodecVHDLEnumerationType(VHDLEnumerationType):
    """Class derived from VHDLEnumerationType to provide codec generator functionality for the enumerated type."""

    def generate_codecs_and_support_functions(self, offset=0):
        """Generate codecs and communication support functions for the enumerated type."""

        template = EnumerationCodecTemplate()

        declarations = ""
        definitions = ""

        if len(self.literals) > 256:
            raise NotImplementedError("Support for enums with more than 256 values are yet to be implemented")

        declarations += template.codec_length_declarations.substitute(type=self.identifier)
        declarations += template.codec_declarations.substitute(type=self.identifier)
        definitions += template.enumeration_codec_definitions.substitute(type=self.identifier, offset=offset)
        declarations += template.to_string_declarations.substitute(type=self.identifier)
        definitions += template.enumeration_to_string_definitions.substitute(type=self.identifier)

        return declarations, definitions


class EnumerationCodecTemplate(DatatypeCodecTemplate):
    """This class contains enumeration codec templates."""

    codec_length_declarations = Template(
        """\
  -- Codec package extension for the type $type

  function code_length_$type(data : $type := $type'left) return natural;
  alias code_length is code_length_$type[$type return natural];
"""
    )

    enumeration_to_string_definitions = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type) return string is
  begin
    return $type'image(data);
  end function;

"""
    )

    enumeration_codec_definitions = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  -- The formulation "type'pos(type'right) + 1" gives the number of literals defined by the enumerated type
  constant length_$type : positive := $type'pos($type'right) + 1;
  constant static_code_length_$type : positive := ceil_div(length_$type, basic_code_nb_values);

  function code_length_$type(data : $type := $type'left) return natural is
  begin
    return static_code_length_$type;
  end function;

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    code(index) := character'val($type'pos(data) + $offset);
    index       := index + code_length_$type;
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    result := $type'val(character'pos(code(index)) - $offset);
    index  := index + code_length_$type;
  end procedure;

  function encode_$type(data : $type) return code_t is
    variable ret_val : code_t(1 to code_length_$type);
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
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return $type is
  begin
    return decode(pop_fix_string(queue, 1));
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
