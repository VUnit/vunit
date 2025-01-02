# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods

"""
Tests the test test_bench module
"""

import unittest
from pathlib import Path
from unittest import mock
from tests.unit.test_test_bench import Entity, Module
from tests.common import with_tempdir
from vunit.test.bench_list import TestBenchList, tb_filter


class TestTestBenchList(unittest.TestCase):
    """
    Tests the test bench
    """

    def test_get_test_benches_in_empty_library(self):
        tb_list = TestBenchList()
        self.assertEqual(tb_list.get_test_benches_in_library("lib"), [])

    @with_tempdir
    def test_tb_filter_requires_runner_cfg(self, tempdir):
        fname = str(Path(tempdir) / "file.vhd")

        design_unit = Entity("tb_entity", file_name=fname)
        design_unit.generic_names = ["runner_cfg"]
        self.assertTrue(tb_filter(design_unit))

        design_unit = Entity("tb_entity", file_name=fname)
        design_unit.generic_names = []
        self.assertFalse(tb_filter(design_unit))

        design_unit = Module("tb_module", file_name=fname)
        design_unit.generic_names = ["runner_cfg"]
        self.assertTrue(tb_filter(design_unit))

        design_unit = Module("tb_module", file_name=fname)
        design_unit.generic_names = []
        self.assertFalse(tb_filter(design_unit))

    @with_tempdir
    def test_tb_filter_match_prefix_and_suffix_only(self, tempdir):
        """
        Issue #263
        """
        with mock.patch("vunit.test.bench_list.LOGGER", autospec=True) as logger:
            design_unit = Entity("mul_tbl_scale", file_name=str(Path(tempdir) / "file.vhd"))
            self.assertFalse(tb_filter(design_unit))
            self.assertFalse(logger.warning.called)

    @with_tempdir
    def test_tb_filter_warning_on_missing_runner_cfg_when_matching_tb_pattern(self, tempdir):
        design_unit = Module("tb_module_not_ok", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = []

        with mock.patch("vunit.test.bench_list.LOGGER", autospec=True) as logger:
            self.assertFalse(tb_filter(design_unit))
            logger.warning.assert_has_calls(
                [
                    mock.call(
                        "%s %s matches testbench name regex %s "
                        "but has no %s runner_cfg and will therefore not be run.\n"
                        "in file %s",
                        "Module",
                        "tb_module_not_ok",
                        "^(tb_.*)|(.*_tb)$",
                        "parameter",
                        design_unit.file_name,
                    )
                ]
            )

    @with_tempdir
    def test_tb_filter_warning_on_runner_cfg_but_not_matching_tb_pattern(self, tempdir):
        design_unit = Entity("entity_ok_but_warning", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]

        with mock.patch("vunit.test.bench_list.LOGGER", autospec=True) as logger:
            self.assertTrue(tb_filter(design_unit))
            logger.warning.assert_has_calls(
                [
                    mock.call(
                        "%s %s has runner_cfg %s but the file name and the %s name does not match regex %s\n"
                        "in file %s",
                        "Entity",
                        "entity_ok_but_warning",
                        "generic",
                        "entity",
                        "^(tb_.*)|(.*_tb)$",
                        design_unit.file_name,
                    )
                ]
            )
