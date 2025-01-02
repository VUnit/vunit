# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Dependency requirements differ between simulators. This file contains
tests to expose those differences.
"""


import unittest
from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent


class TestDependencies(unittest.TestCase):
    """
    Test to expose simulator dependency requirements
    """

    def setUp(self):
        self.data_path = str(ROOT / "dependencies")
        self.output_path = str(ROOT / "dependencies_vunit_out")

    def test_package_body_dependencies(self):
        """
        Some simulators require package users to be re-compiled when
        a package body has changed even though the package header did not change.
        The purpose of this test is to ensure this is handled.
        """

        def run(value):
            """
            Utility function to first run with pkg_body1 then pkg_body2
            """

            dpath = Path(self.data_path)

            tb_pkg_file_name = str(dpath / "tb_pkg.vhd")
            pkg_file_name = str(dpath / "pkg.vhd")
            pkg_body_file_name = str(dpath / ("pkg_body%i.vhd" % value))

            argv = ["--output-path=%s" % self.output_path, "-v"]
            if value == 1:
                argv.append("--clean")

            ui = VUnit.from_argv(argv=argv)
            ui.add_vhdl_builtins()
            lib = ui.add_library("lib")
            lib.add_source_files(tb_pkg_file_name)
            lib.add_source_files(pkg_file_name)
            lib.add_source_files(pkg_body_file_name)
            lib.entity("tb_pkg").set_generic("value", value)

            try:
                ui.main()
            except SystemExit as ex:
                self.assertEqual(ex.code, 0)

        run(1)
        run(2)
