# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the JanusHDL interface
"""

import subprocess
import unittest
from pathlib import Path
from shutil import rmtree
from unittest import mock
from vunit.sim_if.janushdl import JanusHDLInterface
from vunit.project import Project
from vunit.ostools import renew_path, write_file, read_file
from vunit.exceptions import CompileError
from vunit.vhdl_standard import VHDL


class TestJanusHDLInterface(unittest.TestCase):
    """
    Test the JanusHDL interface
    """

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "janushdl_out")
        renew_path(self.output_path)
        self.project = Project()
        self.project.add_library("lib_a", str(Path(self.output_path) / "lib_a"))
        self.project.add_library("lib_b", str(Path(self.output_path) / "lib_b"))
        write_file("a.vhd", "package p is end package;")
        write_file("b.vhd", "library lib_a; use lib_a.p.all; entity e is end entity;")
        self.simif = JanusHDLInterface(output_path=self.output_path, prefix="prefix")

    def tearDown(self):
        rmtree(self.output_path)
        for name in ["a.vhd", "b.vhd"]:
            Path(name).unlink()

    def _add(self, name, library, standard="2008", **compile_options):
        """Add a VHDL file with compile options"""
        source_file = self.project.add_source_file(
            name, library, file_type="vhdl", vhdl_standard=VHDL.standard(standard)
        )
        for key, value in compile_options.items():
            source_file.set_compile_option(key, value)

    @mock.patch("vunit.sim_if.janushdl.check_output", autospec=True, return_value="")
    def test_compile_project_in_one_call(self, check_output):
        self._add("a.vhd", "lib_a", **{"janushdl.a_flags": ["--psl"]})
        self._add("b.vhd", "lib_b", **{"janushdl.a_flags": ["--psl"]})
        self.simif.compile_project(self.project)

        work = Path(self.output_path)
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "jhdl"),
                "-f",
                str(work / "files.f"),
                "--cache",
                str(work / "analysis.jcache"),
                "--std",
                "08",
                "--psl",
                "--analyze-only",
            ],
            env=self.simif.get_env(),
        )
        self.assertEqual(
            read_file(str(work / "files.f")),
            f"library lib_a\n{Path('a.vhd').resolve()}\nlibrary lib_b\n{Path('b.vhd').resolve()}\n",
        )

    @mock.patch("vunit.sim_if.janushdl.check_output", autospec=True, return_value="")
    def test_compile_project_2019_and_1993(self, check_output):
        for standard, flag in [("2019", "19"), ("93", "93")]:
            project = Project()
            project.add_library("lib_a", str(Path(self.output_path) / "lib_a"))
            project.add_source_file("a.vhd", "lib_a", file_type="vhdl", vhdl_standard=VHDL.standard(standard))
            self.simif.compile_project(project)
            command = check_output.call_args[0][0]
            self.assertEqual(command[command.index("--std") + 1], flag)

    def test_rejects_mixed_standards(self):
        self._add("a.vhd", "lib_a", "2008")
        self._add("b.vhd", "lib_b", "2019")
        self.assertRaisesRegex(RuntimeError, "mixed VHDL standards", self.simif.compile_project, self.project)

    def test_rejects_differing_a_flags(self):
        self._add("a.vhd", "lib_a", **{"janushdl.a_flags": ["--psl"]})
        self._add("b.vhd", "lib_b")
        self.assertRaisesRegex(RuntimeError, "janushdl.a_flags", self.simif.compile_project, self.project)

    def test_rejects_external_libraries(self):
        self.project.add_library("ext", self.output_path, is_external=True)
        self.assertRaisesRegex(RuntimeError, "external libraries", self.simif.compile_project, self.project)

    @mock.patch("vunit.sim_if.janushdl.check_output", autospec=True)
    def test_compile_failure_raises(self, check_output):
        check_output.side_effect = subprocess.CalledProcessError(1, "jhdl", output="error: boom")
        self._add("a.vhd", "lib_a")
        self.assertRaises(CompileError, self.simif.compile_project, self.project)
