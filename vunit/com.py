# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from vunit.vhdl_parser import VHDLEnumerationType, VHDLRecordType, VHDLPackage
from glob import glob
from string import Template
from vunit.ostools import read_file, write_file

class CodecGenerator:
    _codec_declarations  = Template("""\
  function encode (
    constant data : $type)
    return string;
  alias encode_$type is encode[$type return string];
  function decode (
    constant code : string)
    return $type;
  alias decode_$type is decode[string return $type];

""")

    _enumeration_codec_definitions = Template("""\
  function encode (
    constant data : $type)
    return string is
  begin
    return $type'image(data);
  end function encode;

  function decode (
    constant code : string)
    return $type is
  begin
    return $type'value(code);
  end function decode;

""")

    _constrained_1d_array_definition = Template("""\
  function encode (
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
  end function encode;

  function decode (
    constant code : string)
    return $type is
    variable ret_val : $type;
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(code, elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

""")

    _constrained_2d_array_definition = Template("""\
  function encode (
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
  end function encode;

  function decode (
    constant code : string)
    return $type is
    variable ret_val : $type;
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(code, elements, ret_val'length(1)*ret_val'length(2), length);
    for i in ret_val'range(1) loop
      for j in ret_val'range(2) loop
        ret_val(i,j) := decode(elements.all(index).all);
        index := index + 1;
      end loop;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

""")

    _unconstrained_1d_array_definition = Template("""\
  function encode (
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
  end function encode;

  function decode (
    constant code : string)
    return $array_type is
    function ret_val_range (
      constant code : string)
      return $array_type is
      constant range_left : $range_type := decode(get_element(code,1));
      constant range_right : $range_type := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));
      variable ret_val_ascending : $array_type(range_left to range_right);
      variable ret_val_descending : $array_type(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : $array_type(ret_val_range(code)'range);
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

""")

    _unconstrained_2d_array_definition = Template("""\
  function encode (
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
  end function encode;

  function decode (
    constant code : string)
    return $array_type is
    function ret_val_range (
      constant code : string)
      return $array_type is
      constant range_left1 : $range_type1 := decode(get_element(code,1));
      constant range_right1 : $range_type1 := decode(get_element(code,2));
      constant is_ascending1 : boolean := decode(get_element(code,3));
      constant range_left2 : $range_type2 := decode(get_element(code,4));
      constant range_right2 : $range_type2 := decode(get_element(code,5));
      constant is_ascending2 : boolean := decode(get_element(code,6));
      variable ret_val_ascending_ascending : $array_type(range_left1 to range_right1, range_left2 to range_right2);
      variable ret_val_ascending_decending : $array_type(range_left1 to range_right1, range_left2 downto range_right2);
      variable ret_val_decending_ascending : $array_type(range_left1 downto range_right1, range_left2 to range_right2);
      variable ret_val_decending_decending : $array_type(range_left1 downto range_right1, range_left2 downto range_right2);
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
    variable ret_val : $array_type(ret_val_range(code)'range(1), ret_val_range(code)'range(2));
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length(1)*ret_val'length(2), length);
    for i in ret_val'range(1) loop
      for j in ret_val'range(2) loop
        ret_val(i,j) := decode(elements.all(index).all);
        index := index + 1;
      end loop;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

""")


    _record_codec_definition = Template("""\
  function encode (
    constant data : $type)
    return string is
  begin
    return create_group($num_of_elements, $element_encodings);
  end function encode;

  function decode (
    constant code : string)
    return $type is
    variable ret_val : $type;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, $num_of_elements, length);
    $element_decodings
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

""")

    _msg_type_record_codec_declaration = Template("""\
  function $name$parameter_part
    return string;
""")

    _msg_type_record_codec_definition = Template("""\
  function $name$parameter_part
    return string is
  begin
    return create_group($num_of_encodings, $encodings);
  end function $name;

""")

    _codec_package = Template("""\
library vunit_lib;
use vunit_lib.string_ops.all;
context vunit_lib.com_context;

use std.textio.all;

use work.$package_name.all;

$use_clauses

package $codec_package_name is
$codec_declarations
end package $codec_package_name;

package body $codec_package_name is
$codec_definitions
end package body $codec_package_name;
""")

    @classmethod
    def generate_codecs(cls, package, codec_package_name, used_packages, output_file):
        # Find the correct package (maybe several in the package file)
        code = read_file(package.source_file.name)
        for p in VHDLPackage.find(code):
            if p.identifier == package.name:
                break
        else:
            raise KeyError(package.name)

        # Create declarations and definitions for enumeration type codecs
        codec_declarations = ''
        codec_definitions = ''
        enumeration_types = {}
        for e in p.enumeration_types:
            codec_declarations += cls._codec_declarations.substitute(type=e.identifier)
            codec_definitions += cls._enumeration_codec_definitions.substitute(type=e.identifier)
            enumeration_types[e.identifier] = e.literals

        # Create declarations and definitions for record type codecs. Remember records which has the first
        # element named "msg_type"
        msg_type_record_types = []
        for r in p.record_types:
            codec_declarations += cls._codec_declarations.substitute(type=r.identifier)
            element_encoding_list = []
            element_decoding_list = []
            num_of_elements = 0
            for e in r.elements:
                for i in e.identifier_list:
                    element_encoding_list.append('encode(data.%s)' % i)
                    element_decoding_list.append('ret_val.%s := decode(elements.all(%d).all);' % (i, num_of_elements))
                    num_of_elements += 1
            element_encodings  = ', '.join(element_encoding_list)
            element_decodings = '\n    '.join(element_decoding_list)
            codec_definitions += cls._record_codec_definition.substitute(type=r.identifier,
                                                            element_encodings=element_encodings,
                                                            num_of_elements=str(num_of_elements),
                                                            element_decodings=element_decodings)
            if r.elements[0].identifier_list[0] == 'msg_type':
                msg_type_record_types.append(r)

        # Create declarations and definitions for array type codecs
        for a in p.array_types:
            has_one_dimension = a.range_left2 is None and a.range_right2 is None and a.range_attribute2 is None and a.range_type2 is None
            is_constrained = a.range_type1 is None and a.range_type2 is None

            if is_constrained:
                if has_one_dimension:
                    codec_declarations += cls._codec_declarations.substitute(type=a.identifier)
                    codec_definitions += cls._constrained_1d_array_definition.substitute(type=a.identifier)
                else:
                    codec_declarations += cls._codec_declarations.substitute(type=a.identifier)
                    codec_definitions += cls._constrained_2d_array_definition.substitute(type=a.identifier)
            else:
                if has_one_dimension:
                    codec_declarations += cls._codec_declarations.substitute(type=a.identifier)
                    codec_definitions += cls._unconstrained_1d_array_definition.substitute(array_type=a.identifier,
                                                                                           range_type=a.range_type1)
                else:
                    codec_declarations += cls._codec_declarations.substitute(type=a.identifier)
                    codec_definitions += cls._unconstrained_2d_array_definition.substitute(array_type=a.identifier,
                                                                                           range_type1=a.range_type1,
                                                                                           range_type2=a.range_type2)

        # Generate "command style" encoders for records with a msg_type element of an enumerated type. There
        # will be command encoder for every value of the enumerated type
        for r in msg_type_record_types:
            msg_type_values = enumeration_types.get(r.elements[0].subtype_indication.type_mark)
            if msg_type_values is not None:
                for value in msg_type_values:
                    parameter_list = []
                    encoding_list = []
                    for e in r.elements:
                        for i in e.identifier_list:
                            if i != 'msg_type':
                                parameter_list.append('    constant %s : %s' % (i, e.subtype_indication.code))
                                encoding_list.append('encode(%s)' % i)
                            else:
                                encoding_list.append("encode(%s'(%s))" % (e.subtype_indication.code, value))
                    if parameter_list == []:
                        parameter_part = ''
                    else:
                        parameter_part = ' (\n' + ';\n'.join(parameter_list) + ')'
                    encodings = ', '.join(encoding_list)

                    codec_declarations += cls._msg_type_record_codec_declaration.substitute(name=value,
                                                                            parameter_part=parameter_part)
                    codec_definitions += cls._msg_type_record_codec_definition.substitute(name=value,
                                                                            parameter_part=parameter_part,
                                                                            num_of_encodings=len(encoding_list),
                                                                            encodings=encodings)
                codec_declarations += '\n'

        # Create extra use clauses
        use_clauses = ''
        for u in used_packages:
            if '.' in u:
                use_clauses += 'use %s.all;\n' % u
            else:
                use_clauses += 'use work.%s.all;\n' % u

        # Create codec package file
        write_file(output_file, cls._codec_package.substitute(codec_declarations=codec_declarations,
                                                              codec_definitions=codec_definitions,
                                                              package_name=package.name,
                                                              codec_package_name=codec_package_name,
                                                              use_clauses=use_clauses))
