# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test suites
"""

from unittest import TestCase
from vunit.test_suites import call_pre_config


class TestTestSuites(TestCase):
    """
    Test the test suites
    """

    def test_call_pre_config_none(self):
        self.assertEqual(call_pre_config(None, "output_path"), True)

    def test_call_pre_config_false(self):
        def pre_config():
            return False
        self.assertEqual(call_pre_config(pre_config, "output_path"), False)

    def test_call_pre_config_true(self):
        def pre_config():
            return True
        self.assertEqual(call_pre_config(pre_config, "output_path"), True)

    def test_call_pre_config_no_return(self):
        def pre_config():
            pass
        self.assertEqual(call_pre_config(pre_config, "output_path"), False)

    def test_call_pre_config_with_output_path(self):

        class WasHere(Exception):
            pass

        def pre_config(output_path):
            """
            Pre config with output path
            """
            self.assertEqual(output_path, "output_path")
            raise WasHere

        self.assertRaises(WasHere, call_pre_config, pre_config, "output_path")
