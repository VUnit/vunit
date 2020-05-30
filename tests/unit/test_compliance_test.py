# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the compliance test.
"""
from unittest import TestCase, mock
from shutil import rmtree
from pathlib import Path
from itertools import product
import re
from vunit.ostools import renew_path
from vunit.vc.verification_component_interface import (
    VerificationComponentInterface,
    LOGGER,
)
from vunit.vc.verification_component import VerificationComponent
from vunit.vc.compliance_test import main
from vunit import VUnit
from vunit.vhdl_parser import VHDLDesignFile, VHDLReference


class TestComplianceTest(TestCase):  # pylint: disable=too-many-public-methods
    """Tests the ComplianceTest class."""

    def setUp(self):
        self.tmp_dir = Path(__file__).parent / "vc_tmp"
        renew_path(str(self.tmp_dir))
        self.vc_contents = """
library ieee
use ieee.std_logic_1164.all;

entity vc is
  generic(vc_h : vc_handle_t);
  port(
    a, b : in std_logic;
    c : in std_logic := '0';
    d, e : inout std_logic;
    f, g : inout std_logic := '1';
    h, i : out std_logic := '0';
    j : out std_logic);

end entity;
"""
        self.vc_path = self.make_file("vc.vhd", self.vc_contents)

        self.vci_contents = """
package vc_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function new_vc(
    logger : logger_t := default_logger;
    actor : actor_t := null_actor;
    checker : checker_t := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return vc_handle_t;
end package;
"""
        self.vci_path = self.make_file("vci.vhd", self.vci_contents)

        self.ui = VUnit.from_argv([])

        self.vc_lib = self.ui.add_library("vc_lib")
        self.vc_lib.add_source_files(str(self.tmp_dir / "*.vhd"))

    def tearDown(self):
        if self.tmp_dir.exists():
            rmtree(self.tmp_dir)

    def make_file(self, file_name, contents):
        """
        Create a file in the temporary directory with contents
        Returns the absolute path to the file.
        """
        full_file_name = (self.tmp_dir / file_name).resolve()
        with full_file_name.open("w") as outfile:
            outfile.write(contents)
        return str(full_file_name)

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_not_finding_vc(self, error_mock):
        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "other_vc", vci
        )
        error_mock.assert_called_once_with("Failed to find VC %s", "other_vc")

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_not_finding_vci(self, error_mock):
        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "other_vc_pkg",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with("Failed to find VCI %s", "other_vc_pkg")

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_on_multiple_entities(self, error_mock):
        vc_contents = """
entity vc1 is
  generic(a : bit);
end entity;

entity vc2 is
  generic(b : bit);
end entity;
"""
        self.vc_lib.add_source_file(self.make_file("vc1_2.vhd", vc_contents))
        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "vc1", vci
        )
        error_mock.assert_called_once_with(
            "%s must contain a single VC entity", self.tmp_dir / "vc1_2.vhd"
        )

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "vc2", vci
        )
        error_mock.assert_called_with(
            "%s must contain a single VC entity", self.tmp_dir / "vc1_2.vhd"
        )

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_on_multiple_package(self, error_mock):
        vci_contents = """
package vc_pkg1 is
end package;

package vc_pkg2 is
end package;
"""
        self.vc_lib.add_source_file(self.make_file("vci1_2.vhd", vci_contents))
        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "vc_pkg1",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with(
            "%s must contain a single VCI package", self.tmp_dir / "vci1_2.vhd"
        )
        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "vc_pkg2",
            "vc_handle_t",
        )
        error_mock.assert_called_with(
            "%s must contain a single VCI package", self.tmp_dir / "vci1_2.vhd"
        )

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_evaluating_vc_generics(self, error_mock):
        vc1_contents = """
entity vc1 is
end entity;
"""
        self.vc_lib.add_source_file(self.make_file("vc1.vhd", vc1_contents))
        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "vc1", vci
        )
        error_mock.assert_called_once_with("%s must have a single generic", "vc1")

        vc2_contents = """
entity vc2 is
  generic(a : bit; b : bit);
end entity;
"""
        self.vc_lib.add_source_file(self.make_file("vc2.vhd", vc2_contents))
        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "vc2", vci
        )
        error_mock.assert_called_with("%s must have a single generic", "vc2")

        vc3_contents = """
entity vc3 is
  generic(a, b : bit);
end entity;
"""
        self.vc_lib.add_source_file(self.make_file("vc3.vhd", vc3_contents))
        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        self.assertRaises(
            SystemExit, VerificationComponent.find, self.vc_lib, "vc3", vci
        )
        error_mock.assert_called_with("%s must have a single generic", "vc3")

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_with_no_constructor(self, error_mock):
        vci_contents = """\
package other_vc_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function create_vc return vc_handle_t;
end package;
"""
        self.vc_lib.add_source_file(self.make_file("other_vci.vhd", vci_contents))

        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "other_vc_pkg",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with(
            "Failed to find a constructor function for vc_handle_t starting with new_"
        )

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_with_wrong_constructor_return_type(self, error_mock):
        vci_contents = """\
package other_vc_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function new_vc return vc_t;
end package;
"""
        self.vc_lib.add_source_file(self.make_file("other_vci.vhd", vci_contents))

        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "other_vc_pkg",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with(
            "Found constructor function new_vc but not with the correct return type vc_handle_t"
        )

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_on_incorrect_constructor_parameters(self, error_mock):
        parameters = dict(
            logger=("logger_t", "default_logger"),
            actor=("actor_t", "null_actor"),
            checker=("checker_t", "null_checker"),
            unexpected_msg_type_policy=("unexpected_msg_type_policy_t", "fail"),
        )
        reasons_for_failure = [
            "missing_parameter",
            "invalid_type",
            "invalid_default_value",
        ]

        for iteration, (invalid_parameter, invalid_reason) in enumerate(
            product(parameters, reasons_for_failure)
        ):
            if (invalid_parameter in ["unexpected_msg_type_policy", "logger"]) and (
                invalid_reason == "invalid_default_value"
            ):
                continue

            vci_contents = (
                """\
package other_vc_%d_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function new_vc(
"""
                % iteration
            )
            for parameter_name, parameter_data in parameters.items():
                if parameter_name != invalid_parameter:
                    vci_contents += "    %s : %s := %s;\n" % (
                        parameter_name,
                        parameter_data[0],
                        parameter_data[1],
                    )
                elif invalid_reason == "invalid_type":
                    vci_contents += "    %s : invalid_type := %s;\n" % (
                        parameter_name,
                        parameter_data[1],
                    )
                elif invalid_reason == "invalid_default_value":
                    vci_contents += "    %s : %s := invalid_default_value;\n" % (
                        parameter_name,
                        parameter_data[0],
                    )

            vci_contents = (
                vci_contents[:-2]
                + """
  ) return vc_handle_t;
end package;
"""
            )
            self.vc_lib.add_source_file(
                self.make_file("other_vci_%d.vhd" % iteration, vci_contents)
            )

            if invalid_reason == "missing_parameter":
                error_msg = (
                    "Found constructor function new_vc for vc_handle_t but the %s parameter is missing"
                    % invalid_parameter
                )
            elif invalid_reason == "invalid_type":
                error_msg = (
                    "Found constructor function new_vc for vc_handle_t but the %s parameter is not of type %s"
                    % (invalid_parameter, parameters[invalid_parameter][0])
                )
            elif invalid_reason == "invalid_default_value":
                error_msg = (
                    "Found constructor function new_vc for vc_handle_t but null_%s is the only allowed "
                    "default value for the %s parameter"
                    % (invalid_parameter, invalid_parameter)
                )

            self.assertRaises(
                SystemExit,
                VerificationComponentInterface.find,
                self.vc_lib,
                "other_vc_%d_pkg" % iteration,
                "vc_handle_t",
            )
            error_mock.assert_called_with(error_msg)

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_on_non_private_handle_elements(self, error_mock):
        vci_contents = """\
package other_vc_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
    foo : bar_t;
  end record;

  impure function new_vc(
    logger : logger_t := default_logger;
    actor : actor_t := null_actor;
    checker : checker_t := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return vc_handle_t;
end package;
"""

        self.vc_lib.add_source_file(self.make_file("other_vci.vhd", vci_contents))

        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "other_vc_pkg",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with(
            "%s in %s doesn't start with p_", "foo", "vc_handle_t"
        )

    @mock.patch("vunit.vc.verification_component_interface.LOGGER.error")
    def test_failing_on_missing_handle_record(self, error_mock):
        vci_contents = """\
package other_vc_pkg is
  type handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function new_vc(
    logger : logger_t := default_logger;
    actor : actor_t := null_actor;
    checker : checker_t := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return vc_handle_t;
end package;
"""

        self.vc_lib.add_source_file(self.make_file("other_vci.vhd", vci_contents))

        self.assertRaises(
            SystemExit,
            VerificationComponentInterface.find,
            self.vc_lib,
            "other_vc_pkg",
            "vc_handle_t",
        )
        error_mock.assert_called_once_with(
            "Failed to find %s record", "vc_handle_t",
        )

    def test_error_on_missing_default_value(self):
        parameters = dict(
            logger=("logger_t", "default_logger"),
            actor=("actor_t", "null_actor"),
            checker=("checker_t", "null_checker"),
            unexpected_msg_type_policy=("unexpected_msg_type_policy_t", "fail"),
        )

        for iteration, parameter_wo_init_value in enumerate(parameters):
            vci_contents = (
                """\
package other_vc_%d_pkg is
  type vc_handle_t is record
    p_std_cfg : std_cfg_t;
  end record;

  impure function new_vc(
"""
                % iteration
            )
            for parameter_name, parameter_data in parameters.items():
                if parameter_name != parameter_wo_init_value:
                    vci_contents += "    %s : %s := %s;\n" % (
                        parameter_name,
                        parameter_data[0],
                        parameter_data[1],
                    )
                else:
                    vci_contents += "    %s : %s;\n" % (
                        parameter_name,
                        parameter_data[0],
                    )

            vci_contents = (
                vci_contents[:-2]
                + """
  ) return vc_handle_t;
end package;
"""
            )
            self.vc_lib.add_source_file(
                self.make_file("other_vci_%d.vhd" % iteration, vci_contents)
            )

            with mock.patch.object(LOGGER, "error") as error_mock:
                self.assertRaises(
                    SystemExit,
                    VerificationComponentInterface.find,
                    self.vc_lib,
                    "other_vc_%d_pkg" % iteration,
                    "vc_handle_t",
                )
                error_mock.assert_called_once_with(
                    "Found constructor function new_vc for vc_handle_t but %s is lacking a default value"
                    % parameter_wo_init_value
                )

    def test_create_vhdl_testbench_template_references(self):
        vc_contents = """\
library std;
library work;
library a_lib;

use std.a.all;
use work.b.c;
use a_lib.x.y;

context work.spam;
context a_lib.eggs;

entity vc2 is
  generic(vc_h : vc_handle_t);
end entity;
"""

        vc_path = self.make_file("vc2.vhd", vc_contents)
        template, _ = VerificationComponent.create_vhdl_testbench_template(
            "vc_lib", vc_path, self.vci_path
        )
        template = VHDLDesignFile.parse(template)
        refs = template.references
        self.assertEqual(len(refs), 13)
        self.assertIn(VHDLReference("library", "vunit_lib"), refs)
        self.assertIn(VHDLReference("library", "vc_lib"), refs)
        self.assertIn(VHDLReference("library", "a_lib"), refs)
        self.assertIn(VHDLReference("package", "std", "a", "all"), refs)
        self.assertIn(VHDLReference("package", "vc_lib", "b", "c"), refs)
        self.assertIn(VHDLReference("package", "vc_lib", "vc_pkg", "all"), refs)
        self.assertIn(VHDLReference("package", "a_lib", "x", "y"), refs)
        self.assertIn(VHDLReference("package", "vunit_lib", "sync_pkg", "all"), refs)
        self.assertIn(VHDLReference("context", "vc_lib", "spam"), refs)
        self.assertIn(VHDLReference("context", "a_lib", "eggs"), refs)
        self.assertIn(VHDLReference("context", "vunit_lib", "vunit_context"), refs)
        self.assertIn(VHDLReference("context", "vunit_lib", "com_context"), refs)
        self.assertIn(VHDLReference("entity", "vc_lib", "vc2"), refs)

    def test_template_with_wrong_name(self):
        template_contents = """\
entity tb_vc2_compliance is
  generic(runner_cfg : string);
end entity;

architecture a of tb_vc2_compliance is
  constant vc_h : vc_handle_t := new_vc;
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""

        template_path = self.make_file("template.vhd", template_contents)

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        vc = VerificationComponent.find(self.vc_lib, "vc", vci)
        self.assertRaises(RuntimeError, vc.create_vhdl_testbench, template_path)

    def test_template_missing_contructor(self):
        template_contents = """\
entity tb_vc_compliance is
  generic(runner_cfg : string);
end entity;

architecture a of tb_vc_compliance is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""

        template_path = self.make_file("template.vhd", template_contents)

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        vc = VerificationComponent.find(self.vc_lib, "vc", vci)
        self.assertRaises(RuntimeError, vc.create_vhdl_testbench, template_path)

    def test_template_missing_runner_cfg(self):
        template_contents = """\
entity tb_vc_compliance is
  generic(foo : bar);
end entity;

architecture a of tb_vc_compliance is
  constant vc_h : vc_handle_t := new_vc;
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""

        template_path = self.make_file("template.vhd", template_contents)

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        vc = VerificationComponent.find(self.vc_lib, "vc", vci)
        self.assertRaises(RuntimeError, vc.create_vhdl_testbench, template_path)

    def test_template_missing_test_runner(self):
        template_contents = """\
entity tb_vc_compliance is
  generic(runner_cfg : string);
end entity;

architecture a of tb_vc_compliance is
  constant vc_h : vc_handle_t := new_vc;
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""

        template_path = self.make_file("template.vhd", template_contents)

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        vc = VerificationComponent.find(self.vc_lib, "vc", vci)
        self.assertRaises(RuntimeError, vc.create_vhdl_testbench, template_path)

    def test_creating_template_without_output_path(self):
        with mock.patch(
            "sys.argv", ["compliance_test.py", "create-vc", self.vc_path, self.vci_path]
        ):
            main()

            self.assertTrue(
                (
                    Path(self.vc_path).parent / ".vc" / "tb_vc_compliance_template.vhd"
                ).exists()
            )

    def test_creating_template_with_output_dir(self):
        output_dir = self.tmp_dir / "template"
        output_dir.mkdir(parents=True)
        with mock.patch(
            "sys.argv",
            [
                "compliance_test.py",
                "create-vc",
                "-o",
                str(output_dir),
                self.vc_path,
                self.vci_path,
            ],
        ):
            main()
            self.assertTrue((output_dir / "tb_vc_compliance_template.vhd").exists())

    def test_creating_template_with_output_file(self):
        output_dir = self.tmp_dir / "template"
        output_dir.mkdir(parents=True)
        output_path = output_dir / "template.vhd"
        with mock.patch(
            "sys.argv",
            [
                "compliance_test.py",
                "create-vc",
                "--output-path",
                str(output_path),
                self.vc_path,
                self.vci_path,
            ],
        ):
            main()
            self.assertTrue(output_path.exists())

    def test_creating_template_with_invalid_output_path(self):
        output_dir = self.tmp_dir / "test"
        output_path = output_dir / "template.vhd"
        with mock.patch(
            "sys.argv",
            [
                "compliance_test.py",
                "create-vc",
                "--output-path",
                str(output_path),
                self.vc_path,
                self.vci_path,
            ],
        ):
            self.assertRaises(IOError, main)

    def test_creating_template_with_default_vc_lib(self):
        with mock.patch(
            "sys.argv", ["compliance_test.py", "create-vc", self.vc_path, self.vci_path]
        ):
            main()
            with (
                Path(self.vc_path).parent / ".vc" / "tb_vc_compliance_template.vhd"
            ).open() as fptr:
                self.assertIsNotNone(
                    re.search(
                        r"library\s+vc_lib\s*;",
                        fptr.read(),
                        re.IGNORECASE | re.MULTILINE,
                    )
                )

    def test_creating_template_with_specified_vc_lib(self):
        with mock.patch(
            "sys.argv",
            [
                "compliance_test.py",
                "create-vc",
                "-l",
                "my_vc_lib",
                self.vc_path,
                self.vci_path,
            ],
        ):
            main()
            with (
                Path(self.vc_path).parent / ".vc" / "tb_vc_compliance_template.vhd"
            ).open() as fptr:
                self.assertIsNotNone(
                    re.search(
                        r"library\s+my_vc_lib\s*;",
                        fptr.read(),
                        re.IGNORECASE | re.MULTILINE,
                    )
                )

    def test_adding_vhdl_testbench(self):
        vc_test_lib = self.ui.add_library("vc_test_lib")

        vci = VerificationComponentInterface.find(self.vc_lib, "vc_pkg", "vc_handle_t")
        vc = VerificationComponent.find(self.vc_lib, "vc", vci)

        vc.add_vhdl_testbench(vc_test_lib, str(self.tmp_dir / "compliance_test"))

        self.assertTrue(
            (self.tmp_dir / "compliance_test" / "tb_vc_compliance.vhd").exists()
        )
        self.assertRaises(
            RuntimeError,
            vc.add_vhdl_testbench,
            vc_test_lib,
            str(self.tmp_dir / "compliance_test"),
        )
