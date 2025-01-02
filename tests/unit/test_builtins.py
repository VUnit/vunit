# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test builtins.py
"""

import unittest
from unittest import mock
from vunit.builtins import BuiltinsAdder


class TestBuiltinsAdder(unittest.TestCase):
    """
    Test BuiltinsAdder class
    """

    @staticmethod
    def test_add_type():
        adder = BuiltinsAdder()
        function = mock.Mock()
        adder.add_type("foo", function)
        adder.add("foo", dict(argument=1))
        function.assert_called_once_with(argument=1)

    def test_adds_dependencies(self):
        adder = BuiltinsAdder()
        function1 = mock.Mock()
        function2 = mock.Mock()
        function3 = mock.Mock()
        function4 = mock.Mock()
        adder.add_type("foo1", function1)
        adder.add_type("foo2", function2, ["foo1"])
        adder.add_type("foo3", function3, ["foo2"])
        adder.add_type("foo4", function4)
        adder.add("foo3", dict(argument=1))
        adder.add("foo2")
        function1.assert_called_once_with()
        function2.assert_called_once_with()
        function3.assert_called_once_with(argument=1)
        self.assertFalse(function4.called)

    def test_runtime_error_on_add_with_different_args(self):
        adder = BuiltinsAdder()
        function = mock.Mock()
        adder.add_type("foo", function)
        adder.add("foo", dict(argument=1))
        try:
            adder.add("foo", dict(argument=2))
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Optional builtin %r added with arguments %r has already been added with arguments %r"
                % ("foo", dict(argument=2), dict(argument=1)),
            )
        else:
            self.fail("RuntimeError not raised")
