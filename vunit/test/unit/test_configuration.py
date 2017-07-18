# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods

"""
Tests the test test_bench module
"""


import unittest

from vunit.configuration import Configuration
from vunit.test.mock_2or3 import mock
from vunit.test.unit.test_test_bench import Entity, out


class TestConfiguration(unittest.TestCase):
    """
    Test the configuration module
    """

    @mock.patch("vunit.configuration.LOGGER")
    def test_warning_on_setting_missing_generic(self, mock_logger):
        design_unit = Entity('tb_entity')
        design_unit.generic_names = ["runner_cfg"]
        config = Configuration('name', design_unit)

        config.set_generic("name123", "value123")
        warning_calls = mock_logger.warning.call_args_list
        self.assertEqual(len(warning_calls), 1)
        call_args = warning_calls[0][0]
        self.assertIn("lib", call_args)
        self.assertIn("tb_entity", call_args)
        self.assertIn("name123", call_args)
        self.assertIn("value123", call_args)

    def test_error_on_setting_unknown_sim_option(self):
        design_unit = Entity('tb_entity')
        design_unit.generic_names = ["runner_cfg"]
        config = Configuration('name', design_unit)

        self.assertRaises(ValueError, config.set_sim_option, "name123", "value123")

    def test_error_on_setting_illegal_value_sim_option(self):
        design_unit = Entity('tb_entity')
        design_unit.generic_names = ["runner_cfg"]
        config = Configuration('name', design_unit)

        self.assertRaises(ValueError, config.set_sim_option, "vhdl_assert_stop_level", "illegal")

    def test_adds_tb_path_generic(self):
        design_unit = Entity('tb_entity_with_tb_path')
        design_unit.generic_names = ["runner_cfg"]
        config = Configuration('name', design_unit)

        design_unit_tb_path = Entity('tb_entity_without_tb_path')
        design_unit_tb_path.generic_names = ["runner_cfg", "tb_path"]
        config_tb_path = Configuration('name', design_unit_tb_path)

        self.assertEqual(config_tb_path.generics["tb_path"], (out() + "/").replace("\\", "/"))
        self.assertNotIn("tb_path", config.generics)
