# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
VHDL parsing functionality
"""

import re
from os.path import abspath
import logging
from vunit.hashing import hash_string
LOGGER = logging.getLogger(__name__)


class VHDLParser(object):
    """
    Parses a single VHDL file
    """

    def __init__(self):
        pass

    @staticmethod
    def parse(code, file_name, content_hash=None):  # pylint: disable=unused-argument
        """
        Parse the VHDL code and return a VHDLDesignFile parse result
        """
        return VHDLDesignFile.parse(code)


class CachedVHDLParser(object):
    """
    Parse a single VHDL file, caching the result to a database
    """

    def __init__(self, database):
        self._database = database

    def parse(self, code, file_name, content_hash=None):
        """
        Parse the VHDL code and return a VHDLDesignFile parse result
        parse result is re-used if content hash found in database
        """
        file_name = abspath(file_name)

        if content_hash is None:
            content_hash = "sha1:" + hash_string(code)
        key = ("CachedVHDLParser.parse(%s)" % file_name).encode()

        if key in self._database:
            design_file, old_content_hash = self._database[key]
            if content_hash == old_content_hash:
                LOGGER.debug("Re-using cached VHDL parse results for %s with content_hash=%s",
                             file_name, content_hash)
                return design_file

        design_file = VHDLDesignFile.parse(code)
        self._database[key] = design_file, content_hash
        return design_file


class VHDLDesignFile(object):  # pylint: disable=too-many-instance-attributes
    """
    Contains VHDL objects found within a file
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 entities=None,
                 packages=None,
                 package_bodies=None,
                 architectures=None,
                 contexts=None,
                 component_instantiations=None,
                 configurations=None,
                 references=None):
        self.entities = [] if entities is None else entities
        self.packages = [] if packages is None else packages
        self.package_bodies = [] if package_bodies is None else package_bodies
        self.architectures = [] if architectures is None else architectures
        self.contexts = [] if contexts is None else contexts
        self.component_instantiations = [] if component_instantiations is None else component_instantiations
        self.configurations = [] if configurations is None else configurations
        self.references = [] if references is None else references

    @classmethod
    def parse(cls, code):
        """
        Return a new VHDLDesignFile instance by parsing the code
        """
        code = remove_comments(code).lower()
        return cls(entities=list(VHDLEntity.find(code)),
                   architectures=list(VHDLArchitecture.find(code)),
                   packages=list(VHDLPackage.find(code)),
                   package_bodies=list(VHDLPackageBody.find(code)),
                   contexts=list(VHDLContext.find(code)),
                   component_instantiations=list(cls._find_component_instantiations(code)),
                   configurations=list(VHDLConfiguration.find(code)),
                   references=list(VHDLReference.find(code)))

    _component_re = re.compile(
        r"[a-zA-Z]\w*\s*\:\s*(?:component)?\s*(?:(?:[a-zA-Z]\w*)\.)?([a-zA-Z]\w*)\s*"
        r"(?:generic|port) map\s*\([\s\w\=\>\,\.\)\(\+\-\'\"]*\);",
        re.IGNORECASE)

    @classmethod
    def _find_component_instantiations(cls, code):
        """
        Return the component name of all component instantiations found within the code
        """
        matches = cls._component_re.findall(code)
        return [comp_name for comp_name in matches]


class VHDLPackageBody(object):
    """
    Representation of a VHDL package body
    """
    def __init__(self, identifier):
        self.identifier = identifier

    _package_body_pattern = re.compile(r"""
        \b                             # Word boundary
        package                        # package keyword
        \s+                            # At least one whitespace
        body                           # body keyword
        \s+                            # At least one whitespace
        (?P<package>[a-zA-Z][\w]*)     # A package
        \s+                            # At least one whitespace
        is                             # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    @classmethod
    def find(cls, code):
        """
        Iterate over new instances of VHDLPackageBody for all package bodies within the code
        """
        matches = cls._package_body_pattern.finditer(code)
        for match in matches:
            yield VHDLPackageBody(match.group('package'))


class VHDLConfiguration(object):
    """
    A configuratio declaration
    """
    def __init__(self, identifier, entity):
        self.identifier = identifier
        self.entity = entity

    _configuration_re = re.compile(r"""
        \b                    # Word boundary
        configuration         # configuration keyword
        \s+                   # At least one whitespace
        (?P<id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        of                    # of keyword
        \s+                   # At least one whitespace
        (?P<entity_id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        is                    # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        """
        Return tuple if library_name, unit_name for all entity instantiations found in the code
        """
        matches = cls._configuration_re.finditer(code)
        return [cls(match.group('id'), match.group('entity_id')) for match in matches]


class VHDLArchitecture(object):
    """
    Representation of a VHDL architecture
    """
    def __init__(self, identifier, entity):
        self.identifier = identifier
        self.entity = entity

    _architecture_re = re.compile(r"""
        \b                    # Word boundary
        architecture          # architecture keyword
        \s+                   # At least one whitespace
        (?P<id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        of                    # of keyword
        \s+                   # At least one whitespace
        (?P<entity_id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        is                    # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        """
        Iterate over new instances of VHDLArchitecture for all architectures within the code
        """
        for arch in cls._architecture_re.finditer(code):
            identifier = arch.group('id')
            entity_id = arch.group('entity_id')
            yield VHDLArchitecture(identifier, entity_id)


class VHDLPackage(object):
    """
    Representation of a VHDL package
    """
    def __init__(self, identifier,
                 enumeration_types, record_types, array_types):
        self.identifier = identifier
        self.enumeration_types = enumeration_types
        self.record_types = record_types
        self.array_types = array_types

    _package_start_re = re.compile(r"""
        \b                    # Word boundary
        package               # package keyword
        \s+                   # At least one whitespace
        (?P<id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        is                    # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        """
        Iterate over new instances of VHDLPackage for all packages within the code
        """
        for package in cls._package_start_re.finditer(code):
            identifier = package.group('id')
            package_end = re.compile(r"""
                \b                            # Word boundary
                end                           # end keyword
                (\s+package)?                 # Optional package keyword
                (\s+""" + identifier + r""")? # Optional identifier
                [\s]*                         # Potential whitespaces
                ;                             # Semicolon
                """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)
            sub_code = code[package.start():]
            match = package_end.search(sub_code)
            if match:
                yield cls.parse(sub_code[:match.end()])

    @classmethod
    def parse(cls, code):
        """
        Return a new VHDLPackage instance for a single package found within the code
        """
        # Extract identifier
        identifier = cls._package_start_re.match(code).group('id')
        enumeration_types = [e for e in VHDLEnumerationType.find(code)]
        record_types = [r for r in VHDLRecordType.find(code)]
        array_types = [a for a in VHDLArrayType.find(code)]

        return cls(identifier, enumeration_types, record_types, array_types)


class VHDLEntity(object):
    """
    Represents a VHDL Entity
    """
    def __init__(self, identifier, generics=None, ports=None):
        self.identifier = identifier

        if generics is not None:
            self.generics = generics
        else:
            self.generics = []

        if ports is not None:
            self.ports = ports
        else:
            self.ports = []

    def add_generic(self, identifier, subtype_code, init_value=None):
        """
        Add a generic to this entity
        """
        self.generics.append(VHDLInterfaceElement(identifier,
                                                  VHDLSubtypeIndication.parse(subtype_code),
                                                  init_value=init_value))

    def add_port(self, identifier, mode, subtype_code, init_value=None):
        """
        Add a port to this entity
        """
        self.ports.append(VHDLInterfaceElement(identifier,
                                               VHDLSubtypeIndication.parse(subtype_code),
                                               init_value=init_value,
                                               mode=mode))

    _entity_start_re = re.compile(r"""
        \b                    # Word boundary
        entity                # entity keyword
        \s+                   # At least one whitespace
        (?P<id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        is                    # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        """
        Iterates over new instances of VHDLEntity for all entities within the code
        """
        for entity in cls._entity_start_re.finditer(code):
            identifier = entity.group('id')
            sub_code = code[entity.start():]
            entity_end_re = re.compile(r"""
                \b                            # Word boundary
                end                           # end keyword
                [\s]*                         # Potential whitespaces
                (entity)?                     # Optional entity keyword
                [\s]*                         # Potential whitespaces
                (""" + identifier + r""")?    # Optional identifier
                [\s]*                         # Potential whitespaces
                ;                             # Semicolon
                """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

            match = entity_end_re.search(sub_code)
            if match:
                yield VHDLEntity.parse(sub_code[:match.end()])

    @classmethod
    def parse(cls, code):
        """
        Create a new instance by parsing the code
        """
        # Extract identifier
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        entity_start = re.compile(r"""
            \b                    # Word boundary
            entity                # entity keyword
            \s+                   # At least one whitespace
            (?P<id>[a-zA-Z][\w]*) # An identifier
            \s+                   # At least one whitespace
            is                    # is keyword
            """, re_flags)
        identifier = entity_start.match(code).group('id')
        # Find generics and ports
        generics = cls._find_generic_clause(code)
        ports = cls._find_port_clause(code)

        return cls(identifier, generics, ports)

    @classmethod
    def _find_generic_clause(cls, code):
        """
        Find and return the generic clause code contents
        """
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        generic_clause_start = re.compile(r"""
            \b                          # Word boundary
            generic                     # generic keyword
            [\s]*                       # Potential whitespaces
            \(                          # Opening parenthesis
            """, re_flags)
        match = generic_clause_start.search(code)
        if match:
            closing_pos = find_closing_delimiter('\\(', '\\)', code[match.end():])
            semicolon = re.compile(r"""
                [\s]*   # Potential whitespaces
                ;       # Semicolon
                """, re_flags)
            match_semicolon = semicolon.match(code[match.end() + closing_pos:])
            if match_semicolon:
                return cls._parse_generic_clause(
                    code[match.start(): match.end() + closing_pos + match_semicolon.end()])
        return []

    @classmethod
    def _find_port_clause(cls, code):
        """
        Find and return the port clause code contents
        """
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        port_clause_start = re.compile(r"""
            ^                             # Beginning of line
            [\s]*                         # Potential whitespaces
            port                          # port keyword
            [\s]*                         # Potential whitespaces
            \(                            # Opening parenthesis
            """, re_flags)
        match = port_clause_start.search(code)
        if match:
            closing_pos = find_closing_delimiter('\\(', '\\)', code[match.end():])
            semicolon = re.compile(r"""
                [\s]*   # Potential whitespaces
                ;       # Semicolon
                """, re_flags)
            match_semicolon = semicolon.match(code[match.end() + closing_pos:])
            if match_semicolon:
                return cls._parse_port_clause(
                    code[match.start(): match.end() + closing_pos + match_semicolon.end()])
        return []

    @staticmethod
    def _split_not_in_par(string, sep):
        """
        Split string at all occurences of sep but not inside of a parenthesis
        """
        result = []
        count = 0
        split = []
        for char in string:
            if char == '(':
                count += 1
            elif char == ')':
                count -= 1

            if char == sep and count == 0:
                result.append("".join(split))
                split = []
            else:
                split.append(char)

        if len(split) > 0:
            result.append("".join(split))

        return result

    _package_generic_re = re.compile(r"\s*package\s+", re.MULTILINE | re.IGNORECASE)
    _type_generic_re = re.compile(r"\s*type\s+", re.MULTILINE | re.IGNORECASE)
    _function_generic_re = re.compile(r"\s*(impure\s+)?(function|procedure)\s+", re.MULTILINE | re.IGNORECASE)

    @classmethod
    def _parse_generic_clause(cls, code):
        """
        Parse the generic clause and return a list of interface elements
        """
        # The generic list is between the outer parenthesis
        generic_list_string = code[code.find('(') + 1: code.rfind(')')]

        # Split the interface elements
        interface_elements = cls._split_not_in_par(generic_list_string, ';')

        generic_list = []
        # Add interface elements to the generic list
        for interface_element in interface_elements:

            if cls._package_generic_re.match(interface_element) is not None:
                # Ignore package generics
                continue

            if cls._type_generic_re.match(interface_element) is not None:
                # Ignore type generics
                continue

            if cls._function_generic_re.match(interface_element) is not None:
                # Ignore function generics
                continue

            generic_list.append(VHDLInterfaceElement.parse(interface_element))

        return generic_list

    @classmethod
    def _parse_port_clause(cls, code):
        """
        Parse the port clause and return a list of interface elements
        """
        # The port list is between the outer parenthesis
        port_list_string = code[code.find('(') + 1: code.rfind(')')]

        # Split the interface elements
        interface_elements = port_list_string.split(';')

        port_list = []
        # Add interface elements to the port list
        for interface_element in interface_elements:
            port_list.append(VHDLInterfaceElement.parse(interface_element, is_signal=True))

        return port_list


class VHDLContext(object):
    """
    Represents a VHDL 2008 context
    """
    def __init__(self, identifier):
        self.identifier = identifier

    _context_start_re = re.compile(r"""
        \b                    # Word boundary
        context               # context keyword
        \s+                   # At least one whitespace
        (?P<id>[a-zA-Z][\w]*) # An identifier
        \s+                   # At least one whitespace
        is                    # is keyword
        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        """
        Iterate over new instances of VHDLContext for a contexts found in the code
        """
        for context in cls._context_start_re.finditer(code):
            identifier = context.group('id')
            yield VHDLContext(identifier=identifier)


class VHDLSubtypeIndication(object):
    """
    Represents a VHDL subtype indication
    """
    def __init__(self, code, type_mark, constraint, array_type):
        self.code = code
        self.type_mark = type_mark
        self.constraint = constraint
        self.array_type = array_type

    @classmethod
    def parse(cls, code):
        """
        Returns a new instance from parsing the code
        """
        # Extract type mark and find out if it's an array type and if a constraint is given.
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        subtype_indication_start = re.compile(r"""
            ^                             # Beginning of line
            [\s]*                         # Potential whitespaces
            (?P<type_mark>[a-zA-Z][\w]*)   # An type mark
            [\s]*                         # Potential whitespaces
            (?P<constraint>\(.*\))?
            """, re_flags)
        subtype_indication_declaration = subtype_indication_start.match(code)
        type_mark = subtype_indication_declaration.group('type_mark')
        constraint = subtype_indication_declaration.group('constraint')

        array_type = type_mark == 'std_logic_vector'
        return cls(code, type_mark, constraint, array_type)

    def __str__(self):
        return self.code


class VHDLInterfaceElement(object):
    """
    Represents a VHDL interface element
    """
    def __init__(self, identifier, subtype_indication, mode=None, init_value=None):
        self.identifier = identifier
        self.mode = mode
        self.subtype_indication = subtype_indication
        self.init_value = init_value

    def without_mode(self):
        """
        @returns A copy of this interface element without a mode
        """
        return VHDLInterfaceElement(self.identifier,
                                    self.subtype_indication,
                                    init_value=self.init_value)

    @classmethod
    def parse(cls, code, is_signal=False):
        """
        Returns a new instance by parsing the code
        """
        if is_signal:
            # Remove 'signal' string if a signal is beeing parsed
            code = code.replace("signal", "")

        interface_element_string = code

        # Extract the identifier
        identifier = interface_element_string.split(':')[0].strip()

        # Extract subtype indication and mode (if any)

        mode_split = interface_element_string.split(':')[1].strip().split(None, 1)
        if cls._is_mode(mode_split[0]):
            mode = mode_split[0]
            subtype_indication = VHDLSubtypeIndication.parse(mode_split[1])
        else:
            mode = None
            subtype_indication = VHDLSubtypeIndication.parse(interface_element_string.split(':')[1].strip())

        # Extract initial value
        init_value_split = interface_element_string.split(':=')
        if len(init_value_split) > 1:
            init_value = init_value_split[1].strip()
        else:
            init_value = None

        return cls(identifier, subtype_indication, mode, init_value)

    @staticmethod
    def _is_mode(code):
        """
        Return True if the code is a mode keyword
        """
        return code in ('in', 'out', 'inout', 'buffer', 'linkage')

    def __str__(self):
        code = self.identifier + " : "

        if self.mode is not None:
            code += self.mode + " "

        code += str(self.subtype_indication)

        if self.init_value is not None:
            code += " := " + self.init_value

        return code


class VHDLEnumerationType(object):
    """Represents a VHDL enumeration type"""
    def __init__(self, identifier, literals):
        self.identifier = identifier
        self.literals = literals

    _enum_declaration_re = re.compile(r"""
        \b                    # Word boundary
        type
        \s+
        (?P<id>[a-zA-Z][\w]*)       # An identifier
        \s+
        is
        \s*\(\s*
        (?P<literals>[a-zA-Z][\w]* # First enumeration literal
        (\s*,\s*[a-zA-Z][\w]*)*)   # More enumeration literals
        \s*\)\s*;""", re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        for enum_type in cls._enum_declaration_re.finditer(code):
            identifier = enum_type.group('id')
            literals = [e.strip() for e in enum_type.group('literals').split(',')]
            yield cls(identifier, literals)


class VHDLElementDeclaration(object):
    """Represents a VHDL element declaration"""
    def __init__(self, identifier_list, subtype_indication):
        self.identifier_list = identifier_list
        self.subtype_indication = subtype_indication


class VHDLRecordType(object):
    """Represents a VHDL record type"""
    def __init__(self, identifier, elements):
        self.identifier = identifier
        self.elements = elements

    _record_declaration_re = re.compile(r"""
        \b                    # Word boundary
        type
        \s+
        (?P<id>[a-zA-Z][\w]*)       # An identifier
        \s+
        is
        \s+
        record
        (?P<elements>.*?)end\s+record""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    @classmethod
    def find(cls, code):
        for record_type in cls._record_declaration_re.finditer(code):
            identifier = record_type.group('id')
            elements = record_type.group('elements').split(';')
            parsed_elements = []
            for element in elements:
                if ':' in element:
                    identifier_list_and_subtype_indication = element.split(':')
                    identifier_list = [i.strip() for i in identifier_list_and_subtype_indication[0].split(',')]
                    subtype_indication = VHDLSubtypeIndication.parse(identifier_list_and_subtype_indication[1].strip())
                    parsed_elements.append(VHDLElementDeclaration(identifier_list, subtype_indication))
            yield cls(identifier, parsed_elements)


class VHDLRange(object):
    """Represents a VHDL Range"""
    def __init__(self, range_type=None, left=None, right=None, attribute=None):
        self.range_type = range_type
        self.left = left
        self.right = right
        self.attribute = attribute


class VHDLArrayType(object):
    """Represents a VHDL array type"""
    def __init__(self, identifier, subtype_indication, range1, range2):
        self.identifier = identifier
        self.subtype_indication = subtype_indication
        self.range1 = range1
        self.range2 = range2

    _constrained_ranges_re = re.compile(r"""
        \s*(?P<range_left1>.+?)
        \s+(to|downto)\s+
        (?P<range_right1>.+?)\s*
        (,
        \s*(?P<range_left2>.+?)
        \s+(to|downto)\s+
        (?P<range_right2>.+?)\s*)?""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _range_attribute_ranges_re = re.compile(r"""
        \s*(?P<range_attribute>[a-zA-Z][\w]*'range)\s*""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _unconstrained_ranges_re = re.compile(r"""
        \s*(?P<range_type1>[a-zA-Z][\w]*)
        \s+range\s+<>\s*
        (,
        \s*(?P<range_type2>[a-zA-Z][\w]*)
        \s+range\s+<>\s*)?""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _constrained_range_re = re.compile(r"""
        \s*(?P<range_left>.+?)
        \s+(to|downto)\s+
        (?P<range_right>.+?)\s*""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _range_attribute_range_re = re.compile(r"""
        \s*(?P<range_attribute>[a-zA-Z][\w]*'range)\s*""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _unconstrained_range_re = re.compile(r"""
        \s*(?P<range_type>[a-zA-Z][\w]*)
        \s+range\s+<>\s*""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    _array_declaration_re = re.compile(r"""
        \b                    # Word boundary
        type
        \s+
        (?P<id>[a-zA-Z][\w]*)
        \s+
        is
        \s+
        array
        \s+\(
        (?P<ranges>.*?)
        \)\s+of\s+
        (?P<subtype_indication>.*?)\s*;""", re.MULTILINE | re.IGNORECASE | re.VERBOSE | re.DOTALL)

    @classmethod
    def find(cls, code):
        """Iterate over new instances of VHDLArrayType for all array types within the code"""
        for array_type in cls._array_declaration_re.finditer(code):
            identifier = array_type.group('id')
            subtype_indication = VHDLSubtypeIndication.parse(array_type.group('subtype_indication'))
            ranges = array_type.group('ranges')
            range1_str, range2_str = cls._split_ranges(ranges)
            range1 = cls._parse_range(range1_str)
            range2 = cls._parse_range(range2_str)

            yield cls(identifier, subtype_indication, range1, range2)

    @staticmethod
    def _split_ranges(ranges):
        """Splits 2D ranges in two. 1D ranges will return None as the second range"""
        level = 0
        index = 0
        if ',' in ranges:
            for char in ranges:
                if char == ',' and level == 0:
                    return ranges[:index], ranges[index + 1:]
                elif char == '(':
                    level += 1
                elif char == ')':
                    level -= 1
                index += 1

        return ranges, None

    @classmethod
    def _parse_range(cls, the_range):
        """Extracts range type, left and right boundary as well as the range when the 'range attribute
        is used"""
        if the_range is None:
            return VHDLRange()

        unconstrained_range = cls._unconstrained_range_re.match(the_range)
        if unconstrained_range is not None:
            range_type = unconstrained_range.group('range_type')
            return VHDLRange(range_type)
        else:
            constrained_range = cls._constrained_range_re.match(the_range)
            range_attribute = cls._range_attribute_range_re.match(the_range)
            if constrained_range is not None:
                range_left = constrained_range.group('range_left')
                range_right = constrained_range.group('range_right')
                return VHDLRange(None, range_left, range_right)
            elif range_attribute is not None:
                range_attribute = range_attribute.group('range_attribute')
                return VHDLRange(attribute=range_attribute)

        return VHDLRange()


def find_closing_delimiter(start, end, code):
    """
    Find the balanced closing position within the code.

    The balanced closing position is defined as the first position of an end marker
    where the number of previous start and end markers are equal
    """
    delimiter_pattern = start + '|' + end
    start = start.replace('\\', '')
    end = end.replace('\\', '')
    delimiters = re.compile(delimiter_pattern)
    count = 1
    for delimiter in delimiters.finditer(code):
        if delimiter.group() == start:
            count += 1
        else:
            count -= 1

        if count == 0:
            return delimiter.end()
    raise ValueError('Failed to find closing delimiter to ' + start + ' in ' + code + '.')


class VHDLReference(object):
    """
    Reference to design unit
    """
    _reference_types = ("package",
                        "context",
                        "entity",
                        "configuration")

    _uses_re = re.compile(r"""
            \b                             # Word boundary
            (?P<use_type>use|context)      # use or context keyword
            \s+                            # At least one whitespace
            (?P<id>[a-zA-Z][\w]*(\.[a-zA-Z][\w]*){1,2})
            (?P<extra>(\s*,\s*[a-zA-Z][\w]*(\.[a-zA-Z][\w]*){1,2})*)
            \s*                            # Potential whitespaces
            ;                              # Semi-colon
    """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def _find_uses(cls, code):
        """
        Find all the libraries and use clasues within the code
        """

        def get_ids(match):
            """
            Get all ids found within the match taking the optinal extra ids of
            library and use clauses into account such as:

            use foo, bar;

            or

            library foo, bar;
            """
            ids = [match.group('id').strip()]
            if match.group('extra'):
                ids += [name.strip() for name in match.group('extra').split(',')[1:]]
            return ids

        references = []
        for match in cls._uses_re.finditer(code):
            for uses in get_ids(match):
                uses = uses.split(".")

                names_within = uses[2:] if len(uses) > 2 else (None,)
                for name_within in names_within:
                    ref = cls(reference_type="package" if match.group("use_type") == "use" else "context",
                              library=uses[0],
                              design_unit=uses[1],
                              name_within=name_within)

                    references.append(ref)
        return references

    _entity_reference_re = re.compile(
        r'\bentity\s+(?P<lib>[a-zA-Z]\w*)\.(?P<ent>[a-zA-Z]\w*)\s*(\((?P<arch>[a-zA-Z]\w*)\))?',
        re.MULTILINE | re.IGNORECASE)

    @classmethod
    def _find_entity_references(cls, code):
        """
        Find all entity references from instantiations or block configurations
        """
        references = []
        for match in cls._entity_reference_re.finditer(code):
            if match.group("arch") is None:
                references.append(cls('entity', match.group("lib"), match.group("ent")))
            else:
                references.append(cls('entity', match.group("lib"), match.group("ent"), match.group("arch")))
        return references

    _configuration_reference_re = re.compile(
        r'\bconfiguration\s+(?P<lib>[a-zA-Z]\w*)\.(?P<cfg>[a-zA-Z]\w*)',
        re.MULTILINE | re.IGNORECASE)

    @classmethod
    def _find_configuration_references(cls, code):
        """
        Find all configuration references within block configurations
        """
        references = []
        for match in cls._configuration_reference_re.finditer(code):
            references.append(cls('configuration', match.group("lib"), match.group("cfg")))
        return references

    _package_instance_re = re.compile(
        r'\bpackage\s+(?P<new_name>[a-zA-Z]\w*)\s+is\s+new\s+(?P<lib>[a-zA-Z]\w*)\.(?P<name>[a-zA-Z]\w*)',
        re.MULTILINE | re.IGNORECASE)

    @classmethod
    def _find_package_instance_references(cls, code):
        """
        Finds all reference causes by package instantiation
        """
        references = []
        for match in cls._package_instance_re.finditer(code):
            references.append(cls('package', match.group("lib"), match.group("name")))
        return references

    @classmethod
    def find(cls, code):
        """
        Find entity, use, context and configuration references within the code
        """
        return (cls._find_uses(code) +
                cls._find_entity_references(code) +
                cls._find_configuration_references(code) +
                cls._find_package_instance_references(code))

    def __init__(self, reference_type, library, design_unit, name_within=None):
        assert reference_type in self._reference_types
        self.reference_type = reference_type
        self.library = library
        self.design_unit = design_unit

        # String "all" may be used to denote all names within
        self.name_within = name_within

    def __repr__(self):
        return "VHDLReference(%r, %r, %r, %r)" % (
            self.reference_type,
            self.library,
            self.design_unit,
            self.name_within)

    def __eq__(self, other):
        return (self.reference_type == other.reference_type and
                self.library == other.library and
                self.design_unit == other.design_unit and
                self.name_within == other.name_within)

    def copy(self):
        return VHDLReference(self.reference_type,
                             self.library,
                             self.design_unit,
                             self.name_within)

    def is_entity_reference(self):
        return self.reference_type == 'entity'

    def is_package_reference(self):
        return self.reference_type == 'package'

    def reference_all_names_within(self):
        return self.name_within == "all"


def remove_comments(code):
    """
    Return the code with comments removed
    """
    return re.sub(r'--[^\n]*', '', code)
