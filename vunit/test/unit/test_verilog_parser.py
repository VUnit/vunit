# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the Verilog parser
"""

from unittest import TestCase
from vunit.parsing.verilog.parser import VerilogParser
from vunit.test.mock_2or3 import mock


class TestVerilogParser(TestCase):  # pylint: disable=too-many-public-methods
    """
    Test of the Verilog parser
    """

    def test_parsing_empty(self):
        design_file = parse("")
        self.assertEqual(design_file.modules, [])

    def test_parse_module(self):
        modules = parse("""\
module true1;
  my_module hello
  "module false";
endmodule
/*
module false
*/
  module true2; // module false
endmodule module true3
endmodule
""").modules
        self.assertEqual(len(modules), 3)
        self.assertEqual(modules[0].name, "true1")
        self.assertEqual(modules[1].name, "true2")
        self.assertEqual(modules[2].name, "true3")

    def test_parse_parameter_without_type(self):
        modules = parse("""\
module foo;
  parameter param1;
  parameter param2 = 1;
endmodule
""").modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_parse_parameter_with_type(self):
        modules = parse("""\
module foo;
  parameter string param1;
  parameter integer param2 = 1;
endmodule
""").modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_nested_modules_are_ignored(self):
        modules = parse("""\
module foo;
  parameter string param1;
  module nested;
    parameter integer param_nested;
  endmodule
  parameter string param2;
endmodule
""").modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_parse_package(self):
        packages = parse("""\
package true1;
endpackage package true2; endpackage
""").packages
        self.assertEqual(len(packages), 2)
        self.assertEqual(packages[0].name, "true1")
        self.assertEqual(packages[1].name, "true2")

    def test_parse_imports(self):
        imports = parse("""\
import true1;
package pkg;
  import true2::*;
endpackage
""").imports
        self.assertEqual(len(imports), 2)
        self.assertEqual(imports[0], "true1")
        self.assertEqual(imports[1], "true2")

    def test_parse_package_references(self):
        package_references = parse("""\
import false1;
import false1::false2::*;
package pkg;
  true1::func(true2::bar());
  true3::foo();
endpackage
""").package_references
        self.assertEqual(len(package_references), 3)
        self.assertEqual(package_references[0], "true1")
        self.assertEqual(package_references[1], "true2")
        self.assertEqual(package_references[2], "true3")

    @mock.patch("vunit.parsing.verilog.parser.LOGGER", autospec=True)
    def test_parse_import_with_bad_argument(self, logger):
        imports = parse("""\
import;
""").imports
        self.assertEqual(len(imports), 0)
        logger.warning.assert_called_once_with(
            "import bad argument\n%s",
            "at file_name.sv line 1:\n"
            "import;\n"
            "      ~")

    @mock.patch("vunit.parsing.verilog.parser.LOGGER", autospec=True)
    def test_parse_import_eof(self, logger):
        imports = parse("""\
import
""").imports
        self.assertEqual(len(imports), 0)
        logger.warning.assert_called_once_with(
            "EOF reached when parsing import\n%s",
            "at file_name.sv line 1:\n"
            "import\n"
            "~~~~~~")

    def test_parse_instances(self):
        instances = parse("""\
module name;
  true1 instance_name1();
  true2 instance_name2(.foo(bar));
  true3 #(.param(1)) instance_name3(.foo(bar));
endmodule
""").instances
        self.assertEqual(len(instances), 3)
        self.assertEqual(instances[0], "true1")
        self.assertEqual(instances[1], "true2")
        self.assertEqual(instances[2], "true3")

    def test_parse_instances_without_crashing(self):
        instances = parse("""\
module name;
endmodule identifier
""").instances
        self.assertEqual(len(instances), 0)

    def test_cached_parsing_smoketest(self):
        code = """\
`include "missing.sv"
module name;
  true1 instance_name1();
  true2 instance_name2(.foo(bar));
  true3 #(.param(1)) instance_name3(.foo(bar));
endmodule
"""
        cache = {}
        parser = VerilogParser(database=cache)
        result = parse(code, parser=parser)
        instances = result.instances
        self.assertEqual(len(instances), 3)
        self.assertEqual(instances[0], "true1")
        self.assertEqual(instances[1], "true2")
        self.assertEqual(instances[2], "true3")

        result = parse(code, parser=parser)
        self.assertEqual(instances, result.instances)
        cache.clear()

        result = parse(code, parser=parser)
        self.assertEqual(instances, result.instances)


def parse(code, parser=None):
    """
    Helper function to parse
    """
    parser = VerilogParser() if parser is None else parser
    with mock.patch("vunit.parsing.tokenizer.read_file", autospec=True) as mock_read_file:
        with mock.patch("vunit.parsing.tokenizer.file_exists", autospec=True) as mock_file_exists:
            def file_exists_side_effect(filename):
                return filename == "file_name.sv"

            def read_file_side_effect(filename):
                """
                Side effect of read file
                """
                assert filename == "file_name.sv"
                return code

            mock_file_exists.side_effect = file_exists_side_effect
            mock_read_file.side_effect = read_file_side_effect

            design_file = parser.parse(code, "file_name.sv", [])
    return design_file
