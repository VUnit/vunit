# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""VerificationComponent class."""

import sys
import re
from pathlib import Path
from re import subn, MULTILINE, IGNORECASE, DOTALL
from vunit.vc.vc_template import (
    TB_TEMPLATE_TEMPLATE,
    ARCHITECTURE_DECLARATIONS_TEMPLATE,
    TEST_RUNNER_TEMPLATE,
    GENERICS_TEMPLATE,
)
from vunit.vhdl_parser import (
    VHDLDesignFile,
    find_closing_delimiter,
    remove_comments,
)
from vunit.vc.verification_component_interface import (
    VerificationComponentInterface,
    create_context_items,
    LOGGER,
)


class VerificationComponent:
    """Represents a Verification Component (VC)."""

    @classmethod
    def find(cls, vc_lib, vc_name, vci):
        """ Finds the specified VC if present.

        :param vc_lib: Library object containing the VC.
        :param vc_name: Name of VC entity.
        :param vci: A VerificationComponentInterface object representing the VCI used by the VC.

        :returns: A VerificationComponent object.
        """

        if not vci:
            LOGGER.error("No VCI provided")
            sys.exit(1)

        try:
            vc_facade = vc_lib.get_entity(vc_name)
        except KeyError:
            LOGGER.error("Failed to find VC %s", vc_name)
            sys.exit(1)

        vc_code = cls.validate(vc_facade.source_file.name)
        if not vc_code:
            sys.exit(1)

        vc_entity = vc_code.entities[0]
        vc_handle_t = vc_entity.generics[0].subtype_indication.type_mark

        if vc_handle_t != vci.vc_constructor.return_type_mark:
            LOGGER.error(
                "VC handle (%s) doesn't match that of the VCI (%s)",
                vc_handle_t,
                vci.vc_constructor.return_type_mark,
            )
            sys.exit(1)

        return cls(vc_facade, vc_code, vc_entity, vc_handle_t, vci)

    def __init__(self, vc_facade, vc_code, vc_entity, vc_handle_t, vci):
        self.vc_facade = vc_facade
        self.vc_code = vc_code
        self.vc_entity = vc_entity
        self.vc_handle_t = vc_handle_t
        self.vci = vci

    @staticmethod
    def validate(vc_path):
        """Validates the existence and contents of the verification component."""
        vc_path = Path(vc_path)
        with vc_path.open() as fptr:
            vc_code = VHDLDesignFile.parse(fptr.read())

            if len(vc_code.entities) != 1:
                LOGGER.error("%s must contain a single VC entity", vc_path)
                return None

            vc_entity = vc_code.entities[0]

            if not (
                (len(vc_entity.generics) == 1)
                and (len(vc_entity.generics[0].identifier_list) == 1)
            ):
                LOGGER.error("%s must have a single generic", vc_entity.identifier)
                return None

            return vc_code

    @staticmethod
    def create_vhdl_testbench_template(vc_lib_name, vc_path, vci_path):
        """
        Creates a template for a VC compliance testbench.

        :param vc_lib_name: Name of the library containing the verification component and its interface.
        :param vc_path: Path to the file containing the verification component entity.
        :param vci_path: Path to the file containing the verification component interface package.

        :returns: The template string and the name of the verification component entity.
        """
        vc_path = Path(vc_path)
        vci_path = Path(vci_path)

        def create_constructor(vc_entity, vc_handle_t, vc_constructor):
            unspecified_parameters = []
            for parameter in vc_constructor.parameter_list:
                if not parameter.init_value:
                    unspecified_parameters += parameter.identifier_list

            constructor = (
                "  -- TODO: Specify a value for all listed parameters. Keep all parameters on separate lines\n"
                if unspecified_parameters
                else ""
            )
            constructor += "  constant %s : %s := %s" % (
                vc_entity.generics[0].identifier_list[0],
                vc_handle_t,
                vc_constructor.identifier,
            )

            if not unspecified_parameters:
                constructor += ";\n"
            else:
                constructor += "(\n"
                for parameter in unspecified_parameters:
                    if parameter in [
                        "actor",
                        "logger",
                        "checker",
                        "unexpected_msg_type_policy",
                    ]:
                        continue
                    constructor += "    %s => ,\n" % parameter
                constructor = constructor[:-2] + "\n  );\n"

            return constructor

        def create_signal_declarations_and_vc_instantiation(vc_entity, vc_lib_name):
            signal_declarations = (
                "  -- TODO: Constrain any unconstrained signal connecting to the DUT.\n"
                if vc_entity.ports
                else ""
            )
            port_mappings = ""
            for port in vc_entity.ports:
                if (port.mode != "out") and port.init_value:
                    for identifier in port.identifier_list:
                        port_mappings += "      %s => open,\n" % identifier
                else:
                    signal_declarations += "  signal %s : %s;\n" % (
                        ", ".join(port.identifier_list),
                        port.subtype_indication,
                    )
                    for identifier in port.identifier_list:
                        port_mappings += "      %s => %s,\n" % (identifier, identifier,)

            vc_instantiation = """  -- DO NOT modify the VC instantiation.
  vc_inst: entity %s.%s
    generic map(%s)""" % (
                vc_lib_name,
                vc_entity.identifier,
                vc_entity.generics[0].identifier_list[0],
            )

            if len(vc_entity.ports) > 0:
                vc_instantiation = (
                    vc_instantiation
                    + """
    port map(
"""
                )

                vc_instantiation += port_mappings[:-2] + "\n    );\n"
            else:
                vc_instantiation += ";\n"

            return signal_declarations, vc_instantiation

        vc_path = Path(vc_path).resolve()
        vci_path = Path(vci_path).resolve()

        vc_code = VerificationComponent.validate(vc_path)
        vc_entity = vc_code.entities[0]
        vc_handle_t = vc_entity.generics[0].subtype_indication.type_mark
        vci_code, vc_constructor = VerificationComponentInterface.validate(
            vci_path, vc_handle_t
        )
        if (not vci_code) or (not vc_constructor):
            return None, None

        (
            signal_declarations,
            vc_instantiation,
        ) = create_signal_declarations_and_vc_instantiation(vc_entity, vc_lib_name)

        initial_package_refs = set(
            [
                "vunit_lib.sync_pkg.all",
                "%s.%s.all" % (vc_lib_name, vci_code.packages[0].identifier),
            ]
        )
        context_items = create_context_items(
            vc_code,
            vc_lib_name,
            initial_library_names=set(["std", "work", "vunit_lib", vc_lib_name]),
            initial_context_refs=set(
                ["vunit_lib.vunit_context", "vunit_lib.com_context"]
            ),
            initial_package_refs=initial_package_refs,
        )

        return (
            TB_TEMPLATE_TEMPLATE.substitute(
                context_items=context_items,
                vc_name=vc_entity.identifier,
                constructor=create_constructor(vc_entity, vc_handle_t, vc_constructor),
                signal_declarations=signal_declarations,
                vc_instantiation=vc_instantiation,
            ),
            vc_entity.identifier,
        )

    def create_vhdl_testbench(self, template_path=None):
        """
        Creates a VHDL VC compliance testbench.

        :param template_path: Path to template file. If None, a default template is assumed.

        :returns: The testbench code as a string.
        """
        template_path = Path(template_path) if template_path is not None else None

        if template_path:
            template_path = Path(template_path).resolve()

        def update_architecture_declarations(code):
            _constructor_call_start_re = re.compile(
                r"\bconstant\s+{vc_handle_name}\s*:\s*{vc_handle_t}\s*:=\s*{vc_constructor_name}".format(
                    vc_handle_name=self.vc_entity.generics[0].identifier_list[0],
                    vc_handle_t=self.vc_handle_t,
                    vc_constructor_name=self.vci.vc_constructor.identifier,
                ),
                MULTILINE | IGNORECASE | DOTALL,
            )

            constructor_call_start = _constructor_call_start_re.search(code)
            if not constructor_call_start:
                raise RuntimeError(
                    "Failed to find call to %s in template_path %s"
                    % (self.vci.vc_constructor.identifier, template_path)
                )

            parameter_start_re = re.compile(r"\s*\(", MULTILINE | IGNORECASE | DOTALL)
            parameter_start = parameter_start_re.match(
                code[constructor_call_start.end() :]
            )

            if parameter_start:
                closing_parenthesis_pos = find_closing_delimiter(
                    "\\(",
                    "\\)",
                    code[constructor_call_start.end() + parameter_start.end() :],
                )

                specified_parameters = (
                    code[
                        constructor_call_start.end()
                        + parameter_start.end() : constructor_call_start.end()
                        + parameter_start.end()
                        + closing_parenthesis_pos
                        - 1
                    ].strip()
                    + ","
                )

            else:
                specified_parameters = ""

            _constructor_call_end_re = re.compile(
                r"\s*;", MULTILINE | IGNORECASE | DOTALL
            )
            if parameter_start:
                search_start = (
                    constructor_call_start.end()
                    + parameter_start.end()
                    + closing_parenthesis_pos
                )
                constructor_call_end_match = _constructor_call_end_re.match(
                    code[search_start:]
                )
            else:
                search_start = constructor_call_start.end()
                constructor_call_end_match = _constructor_call_end_re.match(
                    code[search_start:]
                )

            if not constructor_call_end_match:
                raise RuntimeError(
                    "Missing trailing semicolon for %s in template_path %s"
                    % (self.vci.vc_constructor.identifier, template_path)
                )

            constructor_call_end = search_start + constructor_call_end_match.end()

            default_values = {}
            for parameter in self.vci.vc_constructor.parameter_list:
                for identifier in parameter.identifier_list:
                    default_values[identifier] = parameter.init_value

            architecture_declarations = ARCHITECTURE_DECLARATIONS_TEMPLATE.substitute(
                vc_handle_t=self.vc_handle_t,
                vc_constructor_name=self.vci.vc_constructor.identifier,
                specified_parameters=specified_parameters,
                vc_handle_name=self.vc_entity.generics[0].identifier_list[0],
                default_logger=default_values["logger"]
                if default_values["logger"]
                else 'get_logger("vc_logger")',
                default_actor=default_values["actor"]
                if default_values["actor"]
                else 'new_actor("vc_actor")',
                default_checker=default_values["checker"]
                if default_values["checker"]
                else 'new_checker("vc_checker")',
            )

            return (
                code[: constructor_call_start.start()]
                + architecture_declarations
                + code[constructor_call_end:]
            )

        def update_test_runner(code):
            _test_runner_re = re.compile(
                r"\btest_runner\s*:\s*process.*?end\s+process\s+test_runner\s*;",
                # r"\btest_runner\s*:\s*process",
                MULTILINE | IGNORECASE | DOTALL,
            )

            new_test_runner = TEST_RUNNER_TEMPLATE.substitute(
                vc_handle_name=self.vc_entity.generics[0].identifier_list[0]
            )

            code, num_found_test_runners = subn(
                _test_runner_re, new_test_runner, code, 1
            )
            if not num_found_test_runners:
                raise RuntimeError(
                    "Failed to find test runner in template_path %s" % template_path
                )

            return code

        def update_generics(code):
            _runner_cfg_re = re.compile(
                r"\brunner_cfg\s*:\s*string", MULTILINE | IGNORECASE | DOTALL
            )

            code, num_found_runner_cfg = subn(
                _runner_cfg_re, GENERICS_TEMPLATE, code, 1
            )
            if not num_found_runner_cfg:
                raise RuntimeError(
                    "Failed to find runner_cfg generic in template_path %s"
                    % template_path
                )

            return code

        if template_path:
            template_code = template_path.read_text().lower()
        else:
            template_code, _ = self.create_vhdl_testbench_template(
                self.vc_facade.library,
                self.vc_facade.source_file.name,
                self.vci.vci_facade.source_file.name,
            )
            if not template_code:
                return None
            template_code = template_code.lower()

        design_file = VHDLDesignFile.parse(template_code)
        if (
            design_file.entities[0].identifier
            != "tb_%s_compliance" % self.vc_facade.name
        ):
            raise RuntimeError(
                "%s is not a template_path for %s"
                % (template_path, self.vc_facade.name)
            )

        tb_code = update_architecture_declarations(template_code)
        tb_code = update_test_runner(tb_code)
        tb_code = update_generics(tb_code)

        return remove_comments(tb_code)

    def add_vhdl_testbench(self, vc_test_lib, test_dir, template_path=None):
        """
        Adds a VHDL compliance testbench

        :param vc_test_lib: The name of the library to which the testbench is added.
        :param test_dir: The name of the directory where the testbench file is stored.
        :param template_path: Path to testbench template file. If None, a default template is used.

        :returns: The :class:`.SourceFile` for the added testbench.

        :example:

        .. code-block:: python

           ROOT = Path(__file__).parent()
           prj.add_vhdl_testbench("test_lib", ROOT / "test", ROOT / ".vc" /"vc_template.vhd")

        """
        test_dir = Path(test_dir).resolve()
        template_path = Path(template_path) if template_path is not None else None

        try:
            vc_test_lib.test_bench("tb_%s_compliance" % self.vc_entity.identifier)
            raise RuntimeError(
                "tb_%s_compliance already exists in %s"
                % (self.vc_entity.identifier, vc_test_lib.name)
            )
        except KeyError:
            pass

        if not test_dir.exists():
            test_dir.mkdir(parents=True)

        tb_path = test_dir / ("tb_%s_compliance.vhd" % self.vc_entity.identifier)
        testbench_code = self.create_vhdl_testbench(template_path)
        if not testbench_code:
            return None
        tb_path.write_text(testbench_code)

        tb_file = vc_test_lib.add_source_file(str(tb_path))
        testbench = vc_test_lib.test_bench(
            "tb_%s_compliance" % self.vc_entity.identifier
        )
        test = testbench.test("Test that the actor can be customised")
        test.set_generic("use_custom_actor", True)

        test = testbench.test("Test unexpected message handling")
        test.add_config(
            name="accept_unexpected_msg_type",
            generics=dict(
                unexpected_msg_type_policy="ignore",
                use_custom_logger=True,
                use_custom_actor=True,
            ),
        )
        test.add_config(
            name="fail_unexpected_msg_type_with_null_checker",
            generics=dict(
                unexpected_msg_type_policy="fail",
                use_custom_logger=True,
                use_custom_actor=True,
            ),
        )
        test.add_config(
            name="fail_unexpected_msg_type_with_custom_checker",
            generics=dict(
                unexpected_msg_type_policy="fail",
                use_custom_logger=True,
                use_custom_checker=True,
                use_custom_actor=True,
            ),
        )

        return tb_file
