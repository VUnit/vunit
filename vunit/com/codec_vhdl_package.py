# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Module containing the CodecVHDLPackage class.
"""
from string import Template
from vunit.vhdl_parser import VHDLPackage
from vunit.vhdl_parser import remove_comments
from vunit.com.codec_vhdl_enumeration_type import CodecVHDLEnumerationType
from vunit.com.codec_vhdl_array_type import CodecVHDLArrayType
from vunit.com.codec_vhdl_record_type import CodecVHDLRecordType


class CodecVHDLPackage(VHDLPackage):
    """Class derived from VHDLPackage to provide codec generator functionality for the data types definied
    in the package."""

    def __init__(self, identifier, enumeration_types, record_types, array_types):
        super().__init__(identifier, enumeration_types, record_types, array_types)
        self._template = None

    @classmethod
    def parse(cls, code):
        """
        Return a new VHDLPackage instance for a single package found within the code
        """
        code = remove_comments(code).lower()
        return cls(
            cls._package_start_re.match(code).group("id"),
            list(CodecVHDLEnumerationType.find(code)),
            list(CodecVHDLRecordType.find(code)),
            list(CodecVHDLArrayType.find(code)),
        )

    @classmethod
    def find_named_package(cls, code, name):
        """Find and return the named package in the code (if it exists)"""

        for package in cls.find(code):
            if package.identifier == name:
                return package

        return None

    def generate_codecs_and_support_functions(self):
        """Generate codecs and communication support functions for the data types defined in self."""

        self._template = PackageCodecTemplate()

        declarations = ""
        definitions = ""

        # Record
        (
            new_declarations,
            new_definitions,
        ) = self._generate_record_codec_and_to_string_functions()
        declarations += new_declarations
        definitions += new_definitions

        new_declarations, new_definitions = self._generate_msg_type_encoders()
        declarations += new_declarations
        definitions += new_definitions

        new_declarations, new_definitions = self._generate_get_functions()
        declarations += new_declarations
        definitions += new_definitions

        # Enumerations
        (
            all_msg_types_enumeration_type,
            msg_type_enumeration_types,
        ) = self._create_enumeration_of_all_msg_types()
        if all_msg_types_enumeration_type is not None:
            declarations += self._template.all_msg_types_enumeration_type_declaration.substitute(
                identifier=all_msg_types_enumeration_type.identifier,
                literals=", ".join(all_msg_types_enumeration_type.literals),
            )

        if all_msg_types_enumeration_type is not None:
            declarations += self._template.get_msg_type_declaration.substitute(
                type=all_msg_types_enumeration_type.identifier
            )
            definitions += self._template.get_msg_type_definition.substitute(
                type=all_msg_types_enumeration_type.identifier
            )

        (
            new_declarations,
            new_definitions,
        ) = self._generate_enumeration_codec_and_to_string_functions(
            all_msg_types_enumeration_type, msg_type_enumeration_types
        )
        declarations += new_declarations
        definitions += new_definitions

        # Arrays
        (
            new_declarations,
            new_definitions,
        ) = self._generate_array_codec_and_to_string_functions()
        declarations += new_declarations
        definitions += new_definitions

        return declarations, definitions

    def _generate_record_codec_and_to_string_functions(self):
        """Generate codecs and to_string functions for all record data types."""

        declarations = ""
        definitions = ""
        for record in self.record_types:
            (
                new_declarations,
                new_definitions,
            ) = record.generate_codecs_and_support_functions()
            declarations += new_declarations
            definitions += new_definitions
        return declarations, definitions

    def _generate_array_codec_and_to_string_functions(self):
        """Generate codecs and to_string functions for all array data types."""

        declarations = ""
        definitions = """
  -- Helper function to make tests pass GHDL v0.37
  function get_encoded_length ( constant vec: string ) return integer is
  begin return vec'length; end;

"""
        for array in self.array_types:
            (
                new_declarations,
                new_definitions,
            ) = array.generate_codecs_and_support_functions()
            declarations += new_declarations
            definitions += new_definitions

        return declarations, definitions

    def _create_enumeration_of_all_msg_types(self):
        """Create an enumeration type containing all valid message types. These message types are collected from
        records with a msg_type element which has an enumerated data type."""

        msg_type_enumeration_types = []
        for record in self.record_types:
            if record.elements[0].identifier_list[0] == "msg_type":
                msg_type_enumeration_types.append(record.elements[0].subtype_indication.code)

        msg_type_enumeration_literals = []
        for enum in self.enumeration_types:
            if enum.identifier in msg_type_enumeration_types:
                for literal in enum.literals:
                    if literal in msg_type_enumeration_literals:
                        raise RuntimeError("Different msg_type enumerations may not have the same literals")

                    msg_type_enumeration_literals.append(literal)

        if msg_type_enumeration_literals:
            all_msg_types_enumeration_type = CodecVHDLEnumerationType(
                self.identifier + "_msg_type_t", msg_type_enumeration_literals
            )
        else:
            all_msg_types_enumeration_type = None

        return all_msg_types_enumeration_type, msg_type_enumeration_types

    def _generate_enumeration_codec_and_to_string_functions(
        self, all_msg_types_enumeration_type, msg_type_enumeration_types
    ):
        """Generate codecs and to_string functions for all enumeration data types."""

        declarations = ""
        definitions = ""
        enumeration_offset = 0
        for enum in self.enumeration_types + (
            [all_msg_types_enumeration_type] if all_msg_types_enumeration_type is not None else []
        ):
            if enum.identifier in msg_type_enumeration_types:
                offset = enumeration_offset
                enumeration_offset += len(enum.literals)
            else:
                offset = 0

            (
                new_declarations,
                new_definitions,
            ) = enum.generate_codecs_and_support_functions(offset)
            declarations += new_declarations
            definitions += new_definitions

        return declarations, definitions

    def _generate_msg_type_encoders(self):  # pylint: disable=too-many-locals
        """Generate message type encoders for records with the initial element = msg_type. An encoder is
        generated for each value of the enumeration data type for msg_type. For example, if the record
        has two message types, read and write, and two other fields, addr and data, then two encoders,
        read(addr, data) and write(addr, data) will be generated. These are shorthands for
        encode((<read or write>, addr, data))"""

        declarations = ""
        definitions = ""

        enumeration_types = {}
        for enum in self.enumeration_types:
            enumeration_types[enum.identifier] = enum.literals

        msg_type_record_types = self._get_records_with_an_initial_msg_type_element()

        for record in msg_type_record_types:
            msg_type_values = enumeration_types.get(record.elements[0].subtype_indication.type_mark)

            if msg_type_values is None:
                continue

            for value in msg_type_values:
                parameter_list = []
                parameter_type_list = []
                encoding_list = []
                for element in record.elements:
                    for identifier in element.identifier_list:
                        if identifier != "msg_type":
                            parameter_list.append(f"    constant {identifier!s} : {element.subtype_indication.code!s}")
                            parameter_type_list.append(element.subtype_indication.type_mark)
                            encoding_list.append(f"encode({identifier!s})")
                        else:
                            encoding_list.append(f"encode({element.subtype_indication.code!s}'({value!s}))")

                if not parameter_list:
                    parameter_part = ""
                    alias_signature = value + "[return string];"
                else:
                    parameter_part = " (\n" + ";\n".join(parameter_list) + ")"
                    alias_signature = value + "[" + ", ".join(parameter_type_list) + " return string];"

                encodings = " & ".join(encoding_list)

                declarations += self._template.msg_type_record_codec_declaration.substitute(
                    name=value,
                    parameter_part=parameter_part,
                    alias_signature=alias_signature,
                    alias_name=value + "_msg",
                )
                definitions += self._template.msg_type_record_codec_definition.substitute(
                    name=value,
                    parameter_part=parameter_part,
                    num_of_encodings=len(encoding_list),
                    encodings=encodings,
                )

        return declarations, definitions

    def _generate_get_functions(self):
        """Generate a get function which will return the message type for records"""

        declarations = ""
        definitions = ""

        msg_type_record_types = self._get_records_with_an_initial_msg_type_element()
        msg_type_types = []
        for record in msg_type_record_types:
            msg_type_type = record.elements[0].subtype_indication.code
            if msg_type_type not in msg_type_types:
                msg_type_types.append(msg_type_type)
                declarations += self._template.get_specific_msg_type_declaration.substitute(type=msg_type_type)
                definitions += self._template.get_specific_msg_type_definition.substitute(type=msg_type_type)

        return declarations, definitions

    def _get_records_with_an_initial_msg_type_element(self):
        """Find all record types starting with a msg_type element"""

        msg_type_record_types = []
        for record in self.record_types:
            if record.elements[0].identifier_list[0] == "msg_type":
                msg_type_record_types.append(record)

        return msg_type_record_types


class PackageCodecTemplate(object):
    """This class contains package codec templates."""

    msg_type_record_codec_declaration = Template(
        """\
  function $name$parameter_part
    return string;
  alias $alias_name is $alias_signature

"""
    )

    get_specific_msg_type_declaration = Template(
        """\
  function get_$type (
    constant code : string)
    return $type;

"""
    )

    all_msg_types_enumeration_type_declaration = Template(
        """\
  type $identifier is ($literals);
"""
    )

    get_msg_type_declaration = Template(
        """\
  function get_msg_type (
    constant code : string)
    return $type;

"""
    )

    msg_type_record_codec_definition = Template(
        """\
  function $name$parameter_part
    return string is
  begin
    return $encodings;
  end function $name;

"""
    )

    get_specific_msg_type_definition = Template(
        """\
  function get_$type (
    constant code : string)
    return $type is
  begin
    return decode(code);
  end;

"""
    )

    get_msg_type_definition = Template(
        """\
  function get_msg_type (
    constant code : string)
    return $type is
  begin
    return decode(code);
  end;

"""
    )
