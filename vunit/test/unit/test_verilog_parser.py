# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the Verilog parser
"""

from unittest import TestCase
from vunit.parsing.verilog.parser import VerilogDesignFile


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


def parse(code):
    """
    Helper function to parse
    """
    design_file = VerilogDesignFile.parse(code, "file_name.sv", [])
    return design_file
