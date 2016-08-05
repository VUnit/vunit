# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the CSV log formatter
"""


from __future__ import print_function

import unittest
import os

from vunit.color_printer import COLOR_PRINTER
import vunit.hdl_log_formatter as hdl_log_formatter
from vunit.test.mock_2or3 import mock


class TestVerboseLogFormatter(unittest.TestCase):
    """
    Test the CSV log formatter
    """

    def setUp(self):
        self._calls = []

    def tearDown(self):
        # Restore the default LOG_COLORS value after each test
        hdl_log_formatter.LOG_COLORS = {
            'log_time': {'fg': 'bg', 'bg': None},
            'log_level': {'fg': 'rgbi', 'bg': None},
            'logger_name': {'fg': 'bg', 'bg': None},
            'file_and_line': {'fg': 'rgb', 'bg': None},
            'verbose': {'fg': 'di', 'bg': None},
            'debug': {'fg': 'di', 'bg': None},
            'info': {'fg': None, 'bg': None},
            'warning': {'fg': 'rgi', 'bg': None},
            'error': {'fg': 'ri', 'bg': None},
            'failure': {'fg': 'rgbi', 'bg': 'r'}}

    def test_should_write_with_colors_to_stdout(self):
        self.run_test_with_specs(isatty=True)
        self.assertEqual(
            self._calls,
            ['This text should pass as is\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mINFO\x1b[0m',
             ': ',
             'No prefix',
             '\n',
             '# ',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mDEBUG\x1b[0m',
             ': ',
             '\x1b[30;1mModelSim prefix\x1b[0m',
             '\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mINFO\x1b[0m',
             ': ',
             'Some record \nspanning several lines',
             '\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mHELLO\x1b[0m',
             ': ',
             '\x1b[37;41;1mLogger with level of failure that was renamed '
             'to hello\x1b[0m',
             ''])

    def test_should_write_with_colors_to_a_file(self):
        self.run_test_with_specs(isatty=False)
        self.assertEqual(
            self._calls,
            ['This text should pass as is\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mINFO\x1b[0m',
             ': ',
             'No prefix',
             '\n',
             '# ',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mDEBUG\x1b[0m',
             ': ',
             '\x1b[30;1mModelSim prefix\x1b[0m',
             '\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mINFO\x1b[0m',
             ': ',
             'Some record \nspanning several lines',
             '\n',
             '',
             '\x1b[36m0 ps: \x1b[0m',
             '\x1b[37;1mHELLO\x1b[0m',
             ': ',
             '\x1b[37;41;1mLogger with level of failure that was renamed '
             'to hello\x1b[0m',
             ''])

    def run_test_with_specs(self, isatty):
        """
        Runs a test with given parameters
        """
        stream = mock.Mock(spec_set=MockStream)
        stream.configure_mock(isatty=isatty)

        def side_effect(out):
            """
            Side effect that print output to stdout
            """
            self._calls += [out]

        stream.write.side_effect = side_effect
        formatter = hdl_log_formatter.VerboseLogFormatter(stream, printer=COLOR_PRINTER)
        for test_str in (
                "This text should pass as is\n",
                "0 ps: INFO: Standard log\n",
                "100 ms: INFO in some logger (filename:10): Log with location\n",
                "100 ms: INFO in some logger: Named logger\n"):
            formatter.write(test_str)

    def test_colorize_from_env(self):
        with mock.patch.dict(os.environ,
                             {'VUNIT_LOG_COLORS': 'log_level[fg]=i;'
                                                  'logger_name[bg]=r;'
                                                  'failure[bg]=None'}):
            self.assertEqual(
                hdl_log_formatter.get_colors_from_env(),
                {'log_level': {'fg': 'i', 'bg': None},
                 'logger_name': {'fg': 'bg', 'bg': 'r'},
                 'failure': {'fg': 'rgbi', 'bg': None},
                 'log_time': {'fg': 'bg', 'bg': None},
                 'file_and_line': {'fg': 'rgb', 'bg': None},
                 'verbose': {'fg': 'di', 'bg': None},
                 'debug': {'fg': 'di', 'bg': None},
                 'info': {'fg': None, 'bg': None},
                 'warning': {'fg': 'rgi', 'bg': None},
                 'error': {'fg': 'ri', 'bg': None}})

    def test_get_env_color_fails_with_with_wrong_key(self):
        with self.assertRaises(AssertionError):
            with mock.patch.dict(os.environ,
                                 {'VUNIT_LOG_COLORS': 'foo[fg]=i'}):
                hdl_log_formatter.get_colors_from_env()

    def test_get_env_color_fails_with_with_wrong_scope(self):
        with self.assertRaises(AssertionError):
            with mock.patch.dict(os.environ,
                                 {'VUNIT_LOG_COLORS': 'log_level[background]=i'}):
                hdl_log_formatter.get_colors_from_env()

    def test_get_env_color_fails_with_with_wrong_color(self):
        with self.assertRaises(AssertionError):
            with mock.patch.dict(os.environ,
                                 {'VUNIT_LOG_COLORS': 'log_level[fg]=foo'}):
                hdl_log_formatter.get_colors_from_env()


class MockStream(object):
    """
    Mocks a stream
    """
    write = None
    isatty = None
