# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Module containing the CodecVHDLRecordType class.
"""
from string import Template
from vunit.vhdl_parser import VHDLRecordType
from vunit.com.codec_datatype_template import DatatypeCodecTemplate


class CodecVHDLRecordType(VHDLRecordType):
    """Class derived from VHDLRecordType to provide codec generator functionality for the record type."""

    def generate_codecs_and_support_functions(self):
        """Generate codecs and communication support functions for the record type."""

        template = RecordCodecTemplate()

        declarations = ""
        definitions = ""

        declarations += template.codec_length_declarations.substitute(type=self.identifier)
        declarations += template.codec_declarations.substitute(type=self.identifier)
        declarations += template.to_string_declarations.substitute(type=self.identifier)
        element_encoding_list_procedure = []
        element_encoding_list_function = []
        element_decoding_list = []
        num_of_elements = 0
        for element in self.elements:
            for i in element.identifier_list:
                element_encoding_list_procedure.append(f"encode(data.{i!s}, index, code);")
                element_encoding_list_function.append(f"encode(data.{i!s})")
                element_decoding_list.append(f"decode(code, index, result.{i!s});")
                num_of_elements += 1

        element_encodings_procedure = "\n    ".join(element_encoding_list_procedure)
        element_encodings_function = " & ".join(element_encoding_list_function)
        element_decodings = "\n    ".join(element_decoding_list)
        definitions += template.record_codec_definition.substitute(
            type=self.identifier,
            element_encodings_procedure=element_encodings_procedure,
            element_encodings_function=element_encodings_function,
            element_decodings=element_decodings,
        )
        definitions += template.record_to_string_definition.substitute(
            type=self.identifier,
            element_encoding_list=", ".join(element_encoding_list_function),
            num_of_elements=str(num_of_elements),
        )

        return declarations, definitions


class RecordCodecTemplate(DatatypeCodecTemplate):
    """This class contains record templates."""

    codec_length_declarations = Template(
        """\
  -- Codec package extension for the type $type

  function code_length_$type(data : $type) return natural;
  alias code_length is code_length_$type[$type return natural];
"""
    )

    record_to_string_definition = Template(
        """\
  -- Printing function for the type $type
  function to_string(data : $type) return string is
  begin
    return create_group($num_of_elements, $element_encoding_list);
  end function;
"""
    )

    record_codec_definition = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  ) is
  begin
    $element_encodings_procedure
  end procedure;

  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  ) is
  begin
    $element_decodings
  end procedure;

  function encode_$type(data : $type) return code_t is
  begin
    return $element_encodings_function;
  end function;

  function decode_$type(code : code_t) return $type is
    variable ret_val : $type;
    variable index   : code_index_t := code'left;
  begin
    decode_$type(code, index, ret_val);
    return ret_val;
  end function;

  -- With the current version of the vhdl_parser, it is not possible
  -- to construct the function using the code_length function of the
  -- record constituent
  function code_length_$type(data : $type) return natural is
  begin
    return get_encoded_length(encode_$type(data));
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
