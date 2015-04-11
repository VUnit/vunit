# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
VHDL parsing functionality
"""

import re
from vunit.hashing import hash_bytes
from os.path import abspath

import logging
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
            content_hash = "sha1:" + hash_bytes(code.encode())
        key = "CachedVHDLParser.parse(%s)" % file_name

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
                 instantiations=None,
                 libraries=None,
                 contexts=None,
                 component_instantiations=None):
        self.entities = [] if entities is None else entities
        self.packages = [] if packages is None else packages
        self.package_bodies = [] if package_bodies is None else package_bodies
        self.architectures = [] if architectures is None else architectures
        self.instantiations = [] if instantiations is None else instantiations
        self.libraries = {} if libraries is None else libraries
        self.contexts = [] if contexts is None else contexts
        self.component_instantiations = [] if component_instantiations is None else component_instantiations

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
                   instantiations=list(cls._find_instantiations(code)),
                   libraries=cls._find_libraries(code),
                   contexts=list(VHDLContext.find(code)),
                   component_instantiations=list(cls._find_component_instantiations(code)))

    _entity_re = re.compile(r'[a-zA-Z]\w*\s*\:\s*entity\s+(?P<libName>[a-zA-Z]\w*)\.(?P<entityName>[a-zA-Z]\w*)',
                            re.IGNORECASE)

    @classmethod
    def _find_instantiations(cls, code):
        """
        Return tuple if library_name, unit_name for all entity instantiations found in the code
        """
        matches = cls._entity_re.findall(code)
        return [(library_name, unit_name) for library_name, unit_name in matches]

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

    _library_re = re.compile(r"""
        (^|\A)                         # Beginning of line or start of string
        \s*                            # Potential whitespaces
        library                        # library keyword
        \s+                            # At least one whitespace
        (?P<id>[a-zA-Z][\w]*)          # An identifier
        (?P<extra>(\s*,\s*[a-zA-Z]+[\w])*)
        \s*                            # Potential whitespaces
        ;                              # Semi-colon
    """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    _uses_re = re.compile(r"""
            (^|\A)                         # Beginning of line or start of string
            \s*                            # Potential whitespaces
            (use|context)                  # use or context keyword
            \s+                            # At least one whitespace
            (?P<id>[a-zA-Z][\w]*(\.[a-zA-Z][\w]*){1,2})
            (?P<extra>(\s*,\s*[a-zA-Z][\w]*(\.[a-zA-Z][\w]*){1,2})*)
            \s*                            # Potential whitespaces
            ;                              # Semi-colon
    """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def _find_libraries(cls, code):
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

        libraries = {}
        for match in cls._library_re.finditer(code):
            for library_name in get_ids(match):
                if library_name not in libraries:
                    libraries[library_name] = set()

        for match in cls._uses_re.finditer(code):
            for uses in get_ids(match):
                uses = uses.split(".")
                library_name = uses[0]
                if library_name not in libraries:
                    libraries[library_name] = set()
                libraries[library_name].add(tuple(uses[1:]))
        return libraries


class VHDLPackageBody(object):
    """
    Representation of a VHDL package body
    """
    def __init__(self, identifier):
        self.identifier = identifier

    _package_body_pattern = re.compile(r"""
        (^|\A)                         # Beginning of line or start of string
        \s*                            # Potential whitespaces
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


class VHDLArchitecture(object):
    """
    Representation of a VHDL architecture
    """
    def __init__(self, identifier, entity):
        self.identifier = identifier
        self.entity = entity

    _architecture_re = re.compile(r"""
        (^|\A)                # Beginning of line or start of string
        \s*                   # Potential whitespaces
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
    def __init__(self, identifier, constant_declarations, enumeration_types, record_types, array_types):
        self.identifier = identifier
        self.constant_declarations = constant_declarations
        self.enumeration_types = enumeration_types
        self.record_types = record_types
        self.array_types = array_types

    _package_start_re = re.compile(r"""
        (^|\A)                # Beginning of line or start of string
        \s*                   # Potential whitespaces
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
                (^|\A)                        # Beginning of line or start of string
                [\s]*                         # Potential whitespaces
                end                           # end keyword
                (\s+package)?                 # Optional package keyword
                (\s+""" + identifier + r""")? # Optional identifier
                [\s]*                         # Potential whitespaces
                ;                             # Semicolon
                """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)
            sub_code = code[package.start():]
            match = package_end.search(sub_code)
            if match:
                yield VHDLPackage.parse(sub_code[:match.end()])

    @classmethod
    def parse(cls, code):
        """
        Return a new VHDLPackage instance for a single package found within the code
        """
        # Extract identifier
        identifier = cls._package_start_re.match(code).group('id')
        constant_declarations = cls._find_constant_declarations(code)
        enumeration_types = [e for e in VHDLEnumerationType.find(code)]
        record_types = [r for r in VHDLRecordType.find(code)]
        array_types = [a for a in VHDLArrayType.find(code)]

        return cls(identifier, constant_declarations, enumeration_types, record_types, array_types)

    @classmethod
    def _find_constant_declarations(cls, code):
        """
        Append all constant declarations found within the code to constant_declarations list
        """
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        constant_start = re.compile(r"""
            ^                             # Beginning of line
            [\s]*                         # Potential whitespaces
            constant                      # constant keyword
            \s+                           # At least one whitespace
            (?P<id>[a-zA-Z][\w]*)         # An identifier
            [\s]*                         # Potential whitespaces
            :                             # Colon
            """, re_flags)

        constant_declarations = []
        for constant in constant_start.finditer(code):
            sub_code = code[constant.start():].strip().splitlines()[0].strip()
            constant_declarations.append(VHDLConstantDeclaration.parse(sub_code))
        return constant_declarations


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
        (^|\A)                # Beginning of line or start of string
        \s*                   # Potential whitespaces
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
                (^|\A)                        # Beginning of line or start of string
                [\s]*                         # Potential whitespaces
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
            \A                    # Start of string
            \s*                   # Potential whitespaces
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
            ^                             # Beginning of line
            [\s]*                         # Potential whitespaces
            generic                       # generic keyword
            [\s]*                         # Potential whitespaces
            \(                             # Opening parenthesis
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

    @classmethod
    def _parse_generic_clause(cls, code):
        """
        Parse the generic clause and return a list of interface elements
        """
        # The generic list is between the outer parenthesis
        generic_list_string = code[code.find('(') + 1: code.rfind(')')]

        # Split the interface elements
        interface_elements = generic_list_string.split(';')

        generic_list = []
        # Add interface elements to the generic list
        for interface_element in interface_elements:
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

    def to_str(self, sindent="", indent="  ", as_component=False):
        """
        Convert entity to string, we dont use __str__ so we can have
        indentation start and indentation step parameters

        @param sindent The start indentation
        @param indent The incremental indentation
        """

        if as_component:
            keyword = "component"
        else:
            keyword = "entity"

        code = sindent + keyword + " " + self.identifier + " is\n"

        generic_codes = []
        for generic in self.generics:
            generic_code = sindent + (2 * indent) + str(generic)
            generic_codes.append(generic_code)

        if len(generic_codes) > 0:
            code += sindent + indent + "generic (\n"
            code += ";\n".join(generic_codes)
            code += ");\n"

        port_codes = []
        for port in self.ports:
            port_code = sindent + (2 * indent) + str(port)
            port_codes.append(port_code)

        if len(port_codes) > 0:
            code += sindent + indent + "port (\n"
            code += ";\n".join(port_codes)
            code += ");\n"

        code += sindent + "end " + keyword + ";\n"
        return code

    def to_instantiation_str(self, name, mapping=None, sindent="  ", indent="  "):
        """
        Convert entity to an instantiation string

        @param name The name of the instance
        @param sindent The start indentation
        @param indent The incremental indentation
        """
        if mapping is None:
            mapping = {}

        code = sindent + name + " : " + self.identifier

        generic_codes = []
        for generic in self.generics:
            generic_code = sindent + 2 * indent + generic.identifier
            to_value = mapping.get(generic.identifier,
                                   generic.identifier)
            generic_code += " => " + to_value
            generic_codes.append(generic_code)

        if len(generic_codes) > 0:
            code += "\n"
            code += sindent + indent + "generic map (\n"
            code += ",\n".join(generic_codes)
            code += ")"

        port_codes = []
        for port in self.ports:
            port_code = sindent + 2 * indent + port.identifier
            to_value = mapping.get(port.identifier,
                                   port.identifier)
            port_code += " => " + to_value
            port_codes.append(port_code)

        if len(port_codes) > 0:
            code += "\n"
            code += sindent + indent + "port map (\n"
            code += ",\n".join(port_codes)
            code += ")"

        code += ";\n"
        return code

    def to_signal_declaration_str(self, sindent="  "):
        """
        Convert to code declaring signals for all ports of the entity
        """
        code = ""
        for port in self.ports:
            code += sindent + "signal " + str(port.without_mode()) + ";\n"
        return code


class VHDLContext(object):
    """
    Represents a VHDL 2008 context
    """
    def __init__(self, identifier):
        self.identifier = identifier

    _context_start_re = re.compile(r"""
        (^|\A)                # Beginning of line or start of string
        \s*                   # Potential whitespaces
        context                # context keyword
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

        if type_mark == 'std_logic_vector':
            array_type = True
        else:
            array_type = False
        return cls(code, type_mark, constraint, array_type)

    def __str__(self):
        return self.code


class VHDLConstantDeclaration(object):
    """
    Represents a constant declaration
    """
    def __init__(self, identifier, subtype_indication, expression):
        self.identifier = identifier
        self.subtype_indication = subtype_indication
        self.expression = expression

    @classmethod
    def parse(cls, code):
        """
        Returns a new instance from parsing the code
        """
        # Extract identifier
        re_flags = re.MULTILINE | re.IGNORECASE | re.VERBOSE
        constant_start = re.compile(r"""
            ^                             # Beginning of line
            [\s]*                         # Potential whitespaces
            constant                      # constant keyword
            \s+                           # At least one whitespace
            (?P<id>[a-zA-Z][\w]*)         # An identifier
            [\s]*                         # Potential whitespaces
            :                             # Colon
            """, re_flags)
        constant_declaration = constant_start.match(code)
        identifier = constant_declaration.group('id')

        # Extract subtype indication
        sub_code = code[constant_declaration.end():]
        expression_start = sub_code.find(':=')
        subtype_indication = VHDLSubtypeIndication.parse(sub_code[:expression_start].strip())

        # Extract expression
        sub_code = sub_code[expression_start + 2:]
        expression_end = sub_code.find(';')
        expression = sub_code[: expression_end].strip()
        return cls(identifier, subtype_indication, expression)


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
        if code in ('in', 'out', 'inout', 'buffer', 'linkage'):
            return True
        else:
            return False

    def __str__(self):
        code = self.identifier + " : "

        if self.mode is not None:
            code += self.mode + " "

        code += str(self.subtype_indication)

        if self.init_value is not None:
            code += " := " + self.init_value

        return code


class VHDLEnumerationType(object):
    def __init__(self, identifier, literals):
        self.identifier = identifier
        self.literals = literals

    _enum_declaration_re = re.compile(r"""
        (^|\A)                      # Beginning of line or start of string
        \s*
        type
        \s+
        (?P<id>[a-zA-Z][\w]*)       # An identifier
        \s+
        is
        \s*\(\s*
        (?P<literals>[a-zA-Z][\w]* # First enumeration literal
        (\s*,\s*[a-zA-Z][\w]*)*)   # More enumeration literals
        \s*\)\s*;

        """, re.MULTILINE | re.IGNORECASE | re.VERBOSE)

    @classmethod
    def find(cls, code):
        for enum_type in cls._enum_declaration_re.finditer(code):
            identifier = enum_type.group('id')
            literals = [e.strip() for e in enum_type.group('literals').split(',')]
            yield VHDLEnumerationType(identifier, literals)


class VHDLElementDeclaration(object):
    def __init__(self, identifier_list, subtype_indication):
        self.identifier_list = identifier_list
        self.subtype_indication = subtype_indication


class VHDLRecordType(object):
    def __init__(self, identifier, elements):
        self.identifier = identifier
        self.elements = elements

    _record_declaration_re = re.compile(r"""
        (^|\A)                      # Beginning of line or start of string
        \s*
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
            for e in elements:
                if ':' in e:
                    identifier_list_and_subtype_indication = e.split(':')
                    identifier_list = [i.strip() for i in identifier_list_and_subtype_indication[0].split(',')]
                    subtype_indication = VHDLSubtypeIndication.parse(identifier_list_and_subtype_indication[1].strip())
                    parsed_elements.append(VHDLElementDeclaration(identifier_list, subtype_indication))
            yield VHDLRecordType(identifier, parsed_elements)


class VHDLArrayType(object):
    def __init__(self, identifier, subtype_indication,
                 range_type1=None, range_type2=None,
                 range_left1=None, range_right1=None, range_left2=None, range_right2=None,
                 range_attribute1=None, range_attribute2=None):
        self.identifier = identifier
        self.subtype_indication = subtype_indication
        self.range_type1 = range_type1
        self.range_type2 = range_type2
        self.range_left1 = range_left1
        self.range_right1 = range_right1
        self.range_left2 = range_left2
        self.range_right2 = range_right2
        self.range_attribute1 = range_attribute1
        self.range_attribute2 = range_attribute2

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
        (^|\A)
        \s*
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
        def split_ranges(ranges):
            level = 0
            index = 0
            if ',' in ranges:
                for c in ranges:
                    if c == ',' and level == 0:
                        return ranges[:index], ranges[index + 1:]
                        break
                    elif c == '(':
                        level += 1
                    elif c == ')':
                        level -= 1
                    index += 1

            return ranges, None

        def parse_range(r):
            if r is None:
                return None, None, None, None

            unconstrained_range = cls._unconstrained_range_re.match(r)
            if unconstrained_range is not None:
                range_type = unconstrained_range.group('range_type')
                return range_type, None, None, None
            else:
                constrained_range = cls._constrained_range_re.match(r)
                range_attribute = cls._range_attribute_range_re.match(r)
                if constrained_range is not None:
                    range_left = constrained_range.group('range_left')
                    range_right = constrained_range.group('range_right')
                    return None, range_left, range_right, None
                elif range_attribute is not None:
                    range_attribute = range_attribute.group('range_attribute')
                    return None, None, None, range_attribute

            return None, None, None, None

        for array_type in cls._array_declaration_re.finditer(code):
            identifier = array_type.group('id')
            subtype_indication = VHDLSubtypeIndication.parse(array_type.group('subtype_indication'))

            ranges = array_type.group('ranges')
            range1, range2 = split_ranges(ranges)

            range_type1, range_left1, range_right1, range_attribute1 = parse_range(range1)
            range_type2, range_left2, range_right2, range_attribute2 = parse_range(range2)

            yield VHDLArrayType(identifier, subtype_indication,
                                range_type1, range_type2,
                                range_left1, range_right1, range_left2, range_right2,
                                range_attribute1, range_attribute2)


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


def remove_comments(code):
    """
    Return the code with comments removed
    """
    new_code = ''
    lines = code.split('\n')
    for line in lines:
        line_wo_comments = line.split('--')[0] + '\n'
        new_code = new_code + line_wo_comments

    return new_code
