# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the Verilog parser
"""

from unittest import TestCase, mock
import os
from pathlib import Path
import time
import shutil
from vunit.ostools import renew_path
from vunit.parsing.verilog.parser import VerilogParser


class TestVerilogParser(TestCase):  # pylint: disable=too-many-public-methods
    """
    Test of the Verilog parser
    """

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_verilog_parser_out")
        renew_path(self.output_path)
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.output_path)

    def test_parsing_empty(self):
        design_file = self.parse("")
        self.assertEqual(design_file.modules, [])

    def test_parse_module(self):
        modules = self.parse(
            """\
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
"""
        ).modules
        self.assertEqual(len(modules), 3)
        self.assertEqual(modules[0].name, "true1")
        self.assertEqual(modules[1].name, "true2")
        self.assertEqual(modules[2].name, "true3")

    def test_parse_module_with_keyword_name(self):
        """
        We relax the requirement and allow keywords since standards may be mixed.
        A future enhancement could be to tokenize with awareness of the verilog standard
        """
        modules = self.parse(
            """\
module global;
endmodule

module soft;
endmodule
"""
        ).modules
        self.assertEqual(len(modules), 2)
        self.assertEqual(modules[0].name, "global")
        self.assertEqual(modules[1].name, "soft")

    def test_parse_parameter_without_type(self):
        modules = self.parse(
            """\
module foo;
  parameter param1;
  parameter param2 = 1;
endmodule
"""
        ).modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_parse_parameter_with_type(self):
        modules = self.parse(
            """\
module foo;
  parameter string param1;
  parameter integer param2 = 1;
endmodule
"""
        ).modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_nested_modules_are_ignored(self):
        modules = self.parse(
            """\
module foo;
  parameter string param1;
  module nested;
    parameter integer param_nested;
  endmodule
  parameter string param2;
endmodule
"""
        ).modules
        self.assertEqual(len(modules), 1)
        module = modules[0]
        self.assertEqual(module.name, "foo")
        self.assertEqual(len(module.parameters), 2)
        param1, param2 = module.parameters
        self.assertEqual(param1, "param1")
        self.assertEqual(param2, "param2")

    def test_parse_package(self):
        packages = self.parse(
            """\
package true1;
endpackage package true2; endpackage
"""
        ).packages
        self.assertEqual(len(packages), 2)
        self.assertEqual(packages[0].name, "true1")
        self.assertEqual(packages[1].name, "true2")

    def test_parse_imports(self):
        imports = self.parse(
            """\
import true1;
package pkg;
  import true2::*;
endpackage
"""
        ).imports
        self.assertEqual(len(imports), 2)
        self.assertEqual(imports[0], "true1")
        self.assertEqual(imports[1], "true2")

    def test_parse_package_references(self):
        package_references = self.parse(
            """\
import false1;
import false1::false2::*;
package pkg;
  true1::func(true2::bar());
  true3::foo();
endpackage
"""
        ).package_references
        self.assertEqual(len(package_references), 3)
        self.assertEqual(package_references[0], "true1")
        self.assertEqual(package_references[1], "true2")
        self.assertEqual(package_references[2], "true3")

    @mock.patch("vunit.parsing.verilog.parser.LOGGER", autospec=True)
    def test_parse_import_with_bad_argument(self, logger):
        imports = self.parse(
            """\
import;
"""
        ).imports
        self.assertEqual(len(imports), 0)
        logger.warning.assert_called_once_with(
            "import bad argument\n%s", "at file_name.sv line 1:\n" "import;\n" "      ~"
        )

    @mock.patch("vunit.parsing.verilog.parser.LOGGER", autospec=True)
    def test_parse_import_eof(self, logger):
        imports = self.parse(
            """\
import
"""
        ).imports
        self.assertEqual(len(imports), 0)
        logger.warning.assert_called_once_with(
            "EOF reached when parsing import\n%s",
            "at file_name.sv line 1:\n" "import\n" "~~~~~~",
        )

    def test_parse_instances(self):
        instances = self.parse(
            """\
module name;
  true1 instance_name1();
  true2 instance_name2(.foo(bar));
  true3 #(.param(1)) instance_name3(.foo(bar));
endmodule
"""
        ).instances
        self.assertEqual(len(instances), 3)
        self.assertEqual(instances[0], "true1")
        self.assertEqual(instances[1], "true2")
        self.assertEqual(instances[2], "true3")

    def test_parse_instances_after_block_label(self):
        instances = self.parse(
            """\
module name;
genvar i;
  generate
    for( i=0; i < 10; i = i + 1 )
      begin: INST_GEN
        true1 instance_name1();
    end : INST_GEN
    true2 instance_name2();
  endgenerate
endmodule
"""
        ).instances
        self.assertEqual(len(instances), 2)
        self.assertEqual(instances[0], "true1")
        self.assertEqual(instances[1], "true2")

    def test_parse_instances_without_crashing(self):
        instances = self.parse(
            """\
module name;
endmodule identifier
"""
        ).instances
        self.assertEqual(len(instances), 0)

    def test_can_set_pre_defined_defines(self):
        code = """\
`ifdef foo
`foo
endmodule;
`endif
"""

        result = self.parse(code, defines={"foo": "module mod1;"})
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod1")

    def test_result_is_cached(self):
        code = """\
`include "missing.sv"
module name;
  true1 instance_name1();
  true2 instance_name2(.foo(bar));
  true3 #(.param(1)) instance_name3(.foo(bar));
endmodule
"""
        cache = {}
        result = self.parse(code, cache=cache)
        instances = result.instances
        self.assertEqual(len(instances), 3)
        self.assertEqual(instances[0], "true1")
        self.assertEqual(instances[1], "true2")
        self.assertEqual(instances[2], "true3")

        new_result = self.parse(code, cache=cache)
        self.assertEqual(id(result), id(new_result))
        cache.clear()

        new_result = self.parse(code, cache=cache)
        self.assertNotEqual(id(result), id(new_result))

    def test_cached_parsing_updated_by_changing_file(self):
        code = """\
module mod1;
endmodule
"""
        cache = {}
        result = self.parse(code, cache=cache)
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod1")

        tick()

        code = """\
module mod2;
endmodule
"""
        result = self.parse(code, cache=cache)
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod2")

    def test_cached_parsing_updated_by_includes(self):
        self.write_file(
            "include.svh",
            """
module mod;
endmodule;
""",
        )
        code = """\
`include "include.svh"
"""
        cache = {}
        result = self.parse(code, cache=cache, include_paths=[self.output_path])
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod")

        tick()

        self.write_file(
            "include.svh",
            """
module mod1;
endmodule;

module mod2;
endmodule;
""",
        )
        result = self.parse(code, cache=cache, include_paths=[self.output_path])
        self.assertEqual(len(result.modules), 2)
        self.assertEqual(result.modules[0].name, "mod1")
        self.assertEqual(result.modules[1].name, "mod2")

    def test_cached_parsing_updated_by_higher_priority_file(self):
        cache = {}
        include_paths = [self.output_path, str(Path(self.output_path) / "lower_prio")]

        self.write_file(
            str(Path("lower_prio") / "include.svh"),
            """
module mod_lower_prio;
endmodule;
""",
        )

        code = """\
`include "include.svh"
"""

        result = self.parse(code, cache=cache, include_paths=include_paths)
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod_lower_prio")

        self.write_file(
            "include.svh",
            """
module mod_higher_prio;
endmodule;
""",
        )
        result = self.parse(code, cache=cache, include_paths=include_paths)
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod_higher_prio")

    def test_cached_parsing_updated_by_other_defines(self):
        cache = {}

        code = """\
`ifdef foo
module `foo
endmodule;
`endif
"""

        result = self.parse(code, cache=cache)
        self.assertEqual(len(result.modules), 0)

        result = self.parse(code, cache=cache, defines={"foo": "mod1"})
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod1")

        result = self.parse(code, cache=cache, defines={"foo": "mod2"})
        self.assertEqual(len(result.modules), 1)
        self.assertEqual(result.modules[0].name, "mod2")

    def write_file(self, file_name, contents):
        """
        Write file with contents into output path
        """
        full_name = Path(self.output_path) / file_name
        full_path = full_name.parent
        if not full_path.exists():
            os.makedirs(str(full_path))
        with full_name.open("w") as fptr:
            fptr.write(contents)

    def parse(self, code, include_paths=None, cache=None, defines=None):
        """
        Helper function to parse
        """
        self.write_file("file_name.sv", code)
        cache = cache if cache is not None else {}
        parser = VerilogParser(database=cache)
        include_paths = include_paths if include_paths is not None else []
        design_file = parser.parse("file_name.sv", include_paths, defines)
        return design_file


def tick():
    """
    To get a different file modification time
    """
    time.sleep(0.01)
