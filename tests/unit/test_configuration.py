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
import contextlib
from pathlib import Path
from unittest import mock
from tests.common import with_tempdir, create_tempdir
from tests.unit.test_test_bench import Entity
from vunit.configuration import Configuration, AttributeException


class TestConfiguration(unittest.TestCase):
    """
    Test the configuration module
    """

    @mock.patch("vunit.configuration.LOGGER")
    def test_warning_on_setting_missing_generic(self, mock_logger):
        with _create_config() as config:
            config.set_generic("name123", "value123")
            warning_calls = mock_logger.warning.call_args_list
            self.assertEqual(len(warning_calls), 1)
            call_args = warning_calls[0][0]
            self.assertIn("lib", call_args)
            self.assertIn("tb_entity", call_args)
            self.assertIn("name123", call_args)
            self.assertIn("value123", call_args)

    def test_error_on_setting_unknown_sim_option(self):
        with _create_config() as config:
            self.assertRaises(ValueError, config.set_sim_option, "name123", "value123")

    def test_error_on_setting_illegal_value_sim_option(self):
        with _create_config() as config:
            self.assertRaises(ValueError, config.set_sim_option, "vhdl_assert_stop_level", "illegal")

    def test_sim_option_is_not_mutated(self):
        with _create_config() as config:
            options = ["--foo"]
            config.set_sim_option("ghdl.sim_flags", options)
            options[0] = "--bar"
            self.assertEqual(config.sim_options["ghdl.sim_flags"], ["--foo"])

    def test_does_not_add_tb_path_generic(self):
        with _create_config() as config:
            self.assertNotIn("tb_path", config.generics)

    @with_tempdir
    def test_adds_tb_path_generic(self, tempdir):
        design_unit_tb_path = Entity("tb_entity_without_tb_path", file_name=str(Path(tempdir) / "file.vhd"))
        tb_path = str(Path(tempdir) / "other_path")
        design_unit_tb_path.original_file_name = str(Path(tb_path) / "original_file.vhd")
        design_unit_tb_path.generic_names = ["runner_cfg", "tb_path"]
        config_tb_path = Configuration("name", design_unit_tb_path)
        self.assertEqual(config_tb_path.generics["tb_path"], (tb_path + "/").replace("\\", "/"))

    def test_constructor_adds_no_attributes(self):
        with _create_config() as config:
            self.assertEqual({}, config.attributes)

    def test_constructor_adds_supplied_attributes(self):
        with _create_config(attributes={"foo": "bar"}) as config:
            self.assertEqual({"foo": "bar"}, config.attributes)

    def test_set_attribute_must_start_with_dot(self):
        with _create_config() as config:
            self.assertRaises(AttributeException, config.set_attribute, "foo", "bar")

    def test_call_post_check_none(self):
        self.assertEqual(
            self._call_post_check(None, output_path="output_path", read_output=None),
            True,
        )

    def test_call_post_check_false(self):
        def post_check():
            return False

        self.assertEqual(
            self._call_post_check(post_check, output_path="output_path", read_output=None),
            False,
        )

    def test_call_post_check_true(self):
        def post_check():
            return True

        self.assertEqual(
            self._call_post_check(post_check, output_path="output_path", read_output=None),
            True,
        )

    def test_call_post_check_no_return(self):
        def post_check():
            pass

        self.assertEqual(
            self._call_post_check(post_check, output_path="output_path", read_output=None),
            False,
        )

    def test_call_post_check_with_output_path(self):
        def post_check(output_path):
            """
            Pre config with output path
            """
            self.assertEqual(output_path, "output_path")
            raise WasHere

        self.assertRaises(
            WasHere,
            self._call_post_check,
            post_check,
            output_path="output_path",
            read_output=None,
        )

    def test_call_post_check_with_no_output(self):
        def read_output():
            """
            Should never be called
            """
            assert False

        def post_check():
            """
            Pre config with output path
            """
            raise WasHere

        self.assertRaises(
            WasHere,
            self._call_post_check,
            post_check,
            output_path="output_path",
            read_output=read_output,
        )

    def test_call_post_check_with_output(self):
        output_string = "123___foo\n\nbar"

        def read_output():
            """
            Should never be called
            """
            return output_string

        def post_check(output):
            """
            Pre config with output path
            """
            self.assertEqual(output, output_string)
            raise WasHere

        self.assertRaises(
            WasHere,
            self._call_post_check,
            post_check,
            output_path="output_path",
            read_output=read_output,
        )

    def test_call_pre_config_none(self):
        self.assertEqual(self._call_pre_config(None, "output_path", "simulator_output_path"), True)

    def test_call_pre_config_false(self):
        def pre_config():
            return False

        self.assertEqual(
            self._call_pre_config(pre_config, "output_path", "simulator_output_path"),
            False,
        )

    def test_call_pre_config_true(self):
        def pre_config():
            return True

        self.assertEqual(
            self._call_pre_config(pre_config, "output_path", "simulator_output_path"),
            True,
        )

    def test_call_pre_config_no_return(self):
        def pre_config():
            pass

        self.assertEqual(
            self._call_pre_config(pre_config, "output_path", "simulator_output_path"),
            False,
        )

    def test_call_pre_config_with_output_path(self):
        def pre_config(output_path):
            """
            Pre config with output path
            """
            self.assertEqual(output_path, "output_path")
            raise WasHere

        self.assertRaises(
            WasHere,
            self._call_pre_config,
            pre_config,
            "output_path",
            "simulator_output_path",
        )

    def test_call_pre_config_with_simulator_output_path(self):
        def pre_config(output_path, simulator_output_path):
            """
            Pre config with output path
            """
            self.assertEqual(output_path, "output_path")
            self.assertEqual(simulator_output_path, "simulator_output_path")
            raise WasHere

        self.assertRaises(
            WasHere,
            self._call_pre_config,
            pre_config,
            "output_path",
            "simulator_output_path",
        )

    def test_call_pre_config_class_method(self):
        class MyClass(object):
            """
            Class to test pre_config method
            """

            def __init__(self, value):
                self.value = value

            def pre_config(self, output_path, simulator_output_path):
                """
                Pre config with output path
                """
                assert self.value == 2
                assert output_path == "output_path"
                assert simulator_output_path == "simulator_output_path"
                raise WasHere

        self.assertRaises(
            WasHere,
            self._call_pre_config,
            MyClass(value=2).pre_config,
            "output_path",
            "simulator_output_path",
        )

    @staticmethod
    def _call_pre_config(pre_config, output_path, simulator_output_path):
        """
        Helper method to test call_pre_config method
        """
        with _create_config(pre_config=pre_config) as config:
            return config.call_pre_config(output_path, simulator_output_path)

    @staticmethod
    def _call_post_check(post_check, **kwargs):
        """
        Helper method to test call_post_check method
        """
        with _create_config(post_check=post_check) as config:
            return config.call_post_check(**kwargs)


@contextlib.contextmanager
def _create_config(**kwargs):
    """
    Helper function to create a config
    """
    with create_tempdir() as tempdir:
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        yield Configuration("name", design_unit, **kwargs)


class WasHere(Exception):
    """
    Exception raised to prove code was executed
    """
