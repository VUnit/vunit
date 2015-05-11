# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Module containing the CodecVHDLEnumerationType class.
"""
from string import Template
from vunit.vhdl_parser import VHDLEnumerationType
from vunit.com.codec_datatype_template import DatatypeStdCodecTemplate, DatatypeDebugCodecTemplate


class CodecVHDLEnumerationType(VHDLEnumerationType):
    """Class derived from VHDLEnumerationType to provide codec generator functionality for the enumerated type."""
    def generate_codecs_and_support_functions(self, offset=0, debug=False):
        """Generate codecs and communication support functions for the enumerated type."""
        if not debug:
            template = EnumerationStdCodecTemplate()
        else:
            template = EnumerationDebugCodecTemplate()

        declarations = ''
        definitions = ''

        if len(self.literals) > 256:
            raise NotImplementedError('Support for enums with more than 256 values are yet to be implemented')

        declarations += template.codec_declarations.substitute(type=self.identifier)
        definitions += template.enumeration_codec_definitions.substitute(type=self.identifier, offset=offset)
        declarations += template.to_string_declarations.substitute(type=self.identifier)
        definitions += template.enumeration_to_string_definitions.substitute(type=self.identifier)

        return declarations, definitions


class EnumerationCodecTemplate(object):
    """This class contains enumeration templates common to both standard and debug codecs."""

    enumeration_to_string_definitions = Template("""\
  function to_string (
    constant data : $type)
    return string is
  begin
    return $type'image(data);
  end function to_string;

""")


class EnumerationStdCodecTemplate(DatatypeStdCodecTemplate, EnumerationCodecTemplate):
    """This class contains standard enumeration codec templates."""

    enumeration_codec_definitions = Template("""\
  function encode (
    constant data : $type)
    return string is
    constant offset : natural := $offset;
  begin
    return (1 => character'val($type'pos(data) + offset));
  end function encode;

  procedure decode (
    constant code   : string;
    variable index : inout   positive;
    variable result : out $type) is
    constant offset : natural := $offset;
  begin
    result := $type'val(character'pos(code(index)) - offset);
    index := index + 1;
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

""")


class EnumerationDebugCodecTemplate(DatatypeDebugCodecTemplate, EnumerationCodecTemplate):
    """This class contains debug enumeration codec templates."""

    enumeration_codec_definitions = Template("""\
  function encode (
    constant data : $type)
    return string is
  begin
    return to_string(data);
  end function encode;

  function decode (
    constant code : string)
    return $type is
  begin
    return $type'value(code);
  end function decode;

""")

    enumeration_to_string_definitions = Template("""\
  function to_string (
    constant data : $type)
    return string is
  begin
    return $type'image(data);
  end function to_string;

""")
