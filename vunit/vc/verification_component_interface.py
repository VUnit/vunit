# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""VerificationComponentInterface class."""

import sys
import re
import logging
from pathlib import Path
from vunit.vc.vci_template import TB_TEMPLATE_TEMPLATE, TB_EPILOGUE_TEMPLATE
from vunit.vhdl_parser import (
    VHDLDesignFile,
    VHDLFunctionSpecification,
    remove_comments,
    VHDLRecordType,
)

LOGGER = logging.getLogger(__name__)


def create_context_items(code, lib_name, initial_library_names, initial_context_refs, initial_package_refs):
    """Creates a VHDL snippet with context items found in the provided code and the initial_ arguments."""
    for ref in code.references:
        if ref.is_package_reference() or ref.is_context_reference():
            initial_library_names.add(ref.library_name)

            library_name = ref.library_name if ref.library_name != "work" else lib_name

            if ref.is_context_reference():
                initial_context_refs.add(f"{library_name!s}.{ref.design_unit_name!s}")

            if ref.is_package_reference():
                initial_package_refs.add(f"{library_name!s}.{ref.design_unit_name!s}.{ref.name_within!s}")

    context_items = ""
    for library in sorted(initial_library_names):
        if library not in ["std", "work"]:
            context_items += f"library {library!s};\n"

    for context_ref in sorted(initial_context_refs):
        context_items += f"context {context_ref!s};\n"

    for package_ref in sorted(initial_package_refs):
        context_items += f"use {package_ref!s};\n"

    return context_items


class VerificationComponentInterface:
    """Represents a Verification Component Interface (VCI)."""

    @classmethod
    def find(cls, vci_lib, vci_name, vc_handle_t):
        """Finds the specified VCI if present.

        :param vci_lib: Library object containing the VCI.
        :param vci_name: Name of VCI package.
        :param vc_handle_t: Name of VC handle type.

        :returns: A VerificationComponentInterface object.
        """

        try:
            vci_facade = vci_lib.package(vci_name)
        except KeyError:
            LOGGER.error("Failed to find VCI %s", vci_name)
            sys.exit(1)

        _, vc_constructor = cls.validate(vci_facade.source_file.name, vc_handle_t)
        if not vc_constructor:
            sys.exit(1)

        return cls(vci_facade, vc_constructor)

    @classmethod
    def validate(cls, vci_path, vc_handle_t):
        """Validates the existence and contents of the verification component interface."""
        vci_path = Path(vci_path)

        with vci_path.open() as fptr:
            code = remove_comments(fptr.read())
            vci_code = VHDLDesignFile.parse(code)
            if len(vci_code.packages) != 1:
                LOGGER.error("%s must contain a single VCI package", vci_path)
                return None, None

            if not cls._validate_as_sync(code, vc_handle_t):
                LOGGER.error("%s must provide an as_sync function", vci_path)
                return None, None

            vc_constructor = cls._validate_constructor(code, vc_handle_t)
            if not cls._validate_handle(code, vc_handle_t):
                vc_constructor = None

            return vci_code, vc_constructor

    def __init__(self, vci_facade, vc_constructor):
        self.vci_facade = vci_facade
        self.vc_constructor = vc_constructor

    @staticmethod
    def _validate_as_sync(code, vc_handle_t):
        """Validates the existence and format of the as_sync function."""

        for func in VHDLFunctionSpecification.find(code):
            if not func.identifier.startswith("as_sync"):
                continue

            if func.return_type_mark != "sync_handle_t":
                continue

            if len(func.parameter_list) != 1:
                continue

            if len(func.parameter_list[0].identifier_list) != 1:
                continue

            if func.parameter_list[0].subtype_indication.type_mark != vc_handle_t:
                continue

            return func

        return None

    @staticmethod
    def _validate_constructor(code, vc_handle_t):
        """Validates the existence and format of the verification component constructor."""

        def create_messages(required_parameter_types, expected_default_value):
            messages = [
                "Failed to find a constructor function%s for %s starting with new_",
                "Found constructor function %s but not with the correct return type %s",
            ]

            for parameter_name, parameter_type in required_parameter_types.items():
                messages += [
                    f"Found constructor function %s for %s but the {parameter_name!s} parameter is missing",
                    (
                        f"Found constructor function %s for %s but the {parameter_name} "
                        f"parameter is not of type {parameter_type}"
                    ),
                    f"Found constructor function %s for %s but {parameter_name} is lacking a default value",
                    (
                        f"Found constructor function %s for %s but {expected_default_value[parameter_name]} "
                        f"is the only allowed default value for the {parameter_name} parameter"
                    ),
                ]

            return messages

        def log_error_message(function_score, messages):
            high_score = 0
            best_function = ""
            for function_name, score in function_score.items():
                if score > high_score:
                    high_score = score
                    best_function = function_name

            error_msg = messages[high_score] % (best_function, vc_handle_t)
            LOGGER.error(error_msg)

        required_parameter_types = dict(
            logger="logger_t",
            actor="actor_t",
            checker="checker_t",
            unexpected_msg_type_policy="unexpected_msg_type_policy_t",
        )

        expected_default_value = dict(
            logger="null_logger",
            actor="null_actor",
            checker="null_checker",
            unexpected_msg_type_policy=None,
        )

        messages = create_messages(required_parameter_types, expected_default_value)

        function_score = {}
        for func in VHDLFunctionSpecification.find(code):
            function_score[func.identifier] = 0

            if not func.identifier.startswith("new_"):
                continue
            function_score[func.identifier] += 1

            if func.return_type_mark != vc_handle_t:
                continue
            function_score[func.identifier] += 1

            parameters = {}
            for parameter in func.parameter_list:
                for identifier in parameter.identifier_list:
                    parameters[identifier] = parameter

            for parameter_name, parameter_type in required_parameter_types.items():
                if parameter_name not in parameters:
                    break
                function_score[func.identifier] += 1

                if parameters[parameter_name].subtype_indication.type_mark != parameter_type:
                    break
                function_score[func.identifier] += 1

                if not parameters[parameter_name].init_value:
                    break
                function_score[func.identifier] += 1

                if expected_default_value[parameter_name] and (
                    parameters[parameter_name].init_value != expected_default_value[parameter_name]
                ):
                    break
                function_score[func.identifier] += 1

            if function_score[func.identifier] == len(messages):
                return func

        log_error_message(function_score, messages)

        return None

    @staticmethod
    def _validate_handle(code, vc_handle_t):
        """Validates the existence and format of the verification component handle type."""

        handle_is_valid = True
        for record in VHDLRecordType.find(code):
            if record.identifier == vc_handle_t:
                for element in record.elements:
                    for parameter_name in element.identifier_list:
                        if not parameter_name.lower().startswith("p_"):
                            handle_is_valid = False
                            LOGGER.error(
                                "%s in %s doesn't start with p_",
                                parameter_name,
                                vc_handle_t,
                            )
                return handle_is_valid

        LOGGER.error(
            "Failed to find %s record",
            vc_handle_t,
        )
        return False

    @classmethod
    def create_vhdl_testbench_template(cls, vci_lib_name, vci_path, vc_handle_t):
        """
        Creates a template for a VCI compliance testbench.

        :param vc_lib_name: Name of the library containing the verification component interface.
        :param vci_path: Path to the file containing the verification component interface package.
        :param vc_handle_t: Name of the VC handle type returned by the VC constructor.

        :returns: The template code as a string and the name of the verification component entity.
        """
        vci_path = Path(vci_path)
        vci_code, vc_constructor = cls.validate(vci_path, vc_handle_t)

        context_items = create_context_items(
            vci_code,
            vci_lib_name,
            initial_library_names=set(["std", "work", "vunit_lib", vci_lib_name]),
            initial_context_refs=set(["vunit_lib.vunit_context", "vunit_lib.com_context"]),
            initial_package_refs=set(
                [
                    "vunit_lib.vc_pkg.all",
                    f"{vci_lib_name!s}.{vci_code.packages[0].identifier!s}.all",
                ]
            ),
        )

        unspecified_parameters = [parameter for parameter in vc_constructor.parameter_list if not parameter.init_value]
        if unspecified_parameters:
            constant_declarations = ""
            for parameter in unspecified_parameters:
                for identifier in parameter.identifier_list:
                    if identifier in [
                        "actor",
                        "logger",
                        "checker",
                        "unexpected_msg_type_policy",
                    ]:
                        continue
                    constant_declarations += (
                        f"    constant {identifier!s} : {parameter.subtype_indication.type_mark!s} := ;\n"
                    )
        else:
            constant_declarations = "\n"

        template_code = TB_TEMPLATE_TEMPLATE.substitute(
            context_items=context_items,
            vc_handle_t=vc_handle_t,
            constant_declarations=constant_declarations,
        )

        return (
            template_code,
            vci_code.packages[0].identifier,
        )

    def create_vhdl_testbench(self, template_path=None):
        """
        Creates a VHDL VCI compliance testbench.

        :param template_path: Path to template file. If None, a default template is assumed.

        :returns: The testbench code as a string.
        """
        template_path = Path(template_path) if template_path is not None else None

        if not template_path:
            template_code, _ = self.create_vhdl_testbench_template(
                self.vci_facade.library,
                self.vci_facade.source_file.name,
                self.vc_constructor.return_type_mark,
            )
        else:
            with template_path.open() as fptr:
                template_code = fptr.read()

        test_runner_body_pattern = re.compile(r"\s+-- DO NOT modify this line and the lines below.")
        match = test_runner_body_pattern.search(template_code)
        if not match:
            LOGGER.error("Failed to find body of test_runner in template code.")
            return None

        unspecified_parameters = [
            parameter for parameter in self.vc_constructor.parameter_list if not parameter.init_value
        ]

        def create_handle_assignment(
            handle_name,
            actor=None,
            logger=None,
            checker=None,
            unexpected_msg_type_policy="fail",
        ):
            mark = self.vc_constructor.return_type_mark
            handle_assignment = f"    constant {handle_name!s} : {mark!s} := {self.vc_constructor.identifier!s}(\n"
            for parameter in unspecified_parameters:
                for identifier in parameter.identifier_list:
                    if identifier in [
                        "actor",
                        "logger",
                        "checker",
                        "unexpected_msg_type_policy",
                    ]:
                        continue
                    handle_assignment += f"      {identifier!s} => {identifier!s},\n"
            for formal, actual in dict(
                actor=actor,
                logger=logger,
                checker=checker,
                unexpected_msg_type_policy=unexpected_msg_type_policy,
            ).items():
                if actual:
                    handle_assignment += f"      {formal!s} => {actual!s},\n"

            handle_assignment = handle_assignment[:-2] + "\n    );"

            return handle_assignment

        testbench_code = template_code[: match.start()] + TB_EPILOGUE_TEMPLATE.substitute(
            vc_handle_t=self.vc_constructor.return_type_mark,
            vc_constructor_name=self.vc_constructor.identifier,
            handle1=create_handle_assignment(
                "handle1",
                actor="actor1",
                logger="logger1",
                checker="checker1",
                unexpected_msg_type_policy="fail",
            ),
            handle2=create_handle_assignment(
                "handle2",
                actor="actor2",
                logger="logger2",
                checker="checker2",
                unexpected_msg_type_policy="ignore",
            ),
            handle3=create_handle_assignment(
                "handle3",
                actor="actor3",
                checker="checker3",
                unexpected_msg_type_policy="fail",
            ),
            handle4=create_handle_assignment(
                "handle4",
                actor="actor4",
                logger="null_logger",
                checker="checker4",
                unexpected_msg_type_policy="fail",
            ),
            handle5=create_handle_assignment(
                "handle5",
                actor="actor5",
                unexpected_msg_type_policy="fail",
            ),
            handle6=create_handle_assignment(
                "handle6",
                actor="actor6",
                checker="null_checker",
                unexpected_msg_type_policy="fail",
            ),
            handle7=create_handle_assignment(
                "handle7",
                actor="actor7",
                logger="logger6",
                unexpected_msg_type_policy="fail",
            ),
        )

        return testbench_code

    def add_vhdl_testbench(self, vci_test_lib, test_dir, template_path=None):
        """
        Adds a VHDL compliance testbench

        :param vci_test_lib: The name of the library to which the testbench is added.
        :param test_dir: The name of the directory where the testbench file is stored.
        :param template_path: Path to testbench template file. If None, a default template is used.

        :returns: The :class:`.SourceFile` for the added testbench.

        :example:

        .. code-block:: python

           ROOT = Path(__file__).parent
           prj.add_vhdl_testbench("test_lib", ROOT / "test", ROOT / ".vc" / "vc_template.vhd")

        """
        template_path = Path(template_path).resolve() if template_path is not None else None
        test_dir = Path(test_dir).resolve()

        try:
            vci_test_lib.test_bench(f"tb_{self.vci_facade.name!s}_{self.vc_constructor.return_type_mark!s}_compliance")
            raise RuntimeError(f"tb_{self.vci_facade.name!s}_compliance already exists in {vci_test_lib.name!s}")
        except KeyError:
            pass

        if not test_dir.exists():
            test_dir.mkdir(parents=True)

        tb_path = test_dir / (f"tb_{self.vci_facade.name!s}_{self.vc_constructor.return_type_mark!s}_compliance.vhd")
        testbench_code = self.create_vhdl_testbench(template_path)
        if not testbench_code:
            return None
        tb_path.write_text(testbench_code)

        return vci_test_lib.add_source_file(tb_path)
