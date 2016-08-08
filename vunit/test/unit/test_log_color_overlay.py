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
import vunit.log_color_overlay as log_color_overlay
from vunit.test.mock_2or3 import mock


class TestVerboseLogFormatter(unittest.TestCase):
    """
    Test the CSV log formatter
    """

    def tearDown(self):
        # Restore the default LOG_COLORS value after each test
        log_color_overlay.LOG_COLORS = {
            'log_time': {'fg': 'bg', 'bg': None},
            'log_level': {'fg': 'rgbi', 'bg': None},
            'log_source': {'fg': 'bg', 'bg': None},
            'file_and_line': {'fg': 'rgb', 'bg': None},
            'verbose': {'fg': 'di', 'bg': None},
            'debug': {'fg': 'di', 'bg': None},
            'info': {'fg': None, 'bg': None},
            'warning': {'fg': 'rgi', 'bg': None},
            'error': {'fg': 'ri', 'bg': None},
            'failure': {'fg': 'rgbi', 'bg': 'r'}}

    def test_coloring_vunit_logs_to_stdout(self):
        self.run_vunit_log_coloring_test(isatty=True)

    def test_coloring_vunit_logs_to_a_file(self):
        self.run_vunit_log_coloring_test(isatty=False)

    def run_vunit_log_coloring_test(self, isatty):
        """
        Runs a test with given parameters
        """
        calls = []

        def side_effect(text, output_file=None, fg=None, bg=None):
            """
            Side effect that print output to stdout
            """
            calls.append([text, output_file, fg, bg])

        # Records will be colored by the printer. Mocking the write
        # command allows the need to check ASCII escape sequences
        printer = COLOR_PRINTER
        printer.write = mock.MagicMock()
        printer.write.side_effect = side_effect
        # Mock stream
        stream = mock.Mock(spec_set=MockStream)
        stream.configure_mock(isatty=isatty)

        formatter = log_color_overlay.LogColorOverlay(
            stream=stream, printer=printer)

        for test_str in (
                "A line that should not be changed\n",
                "0 ps: INFO: Standard log\n",
                "100 ms: INFO in some logger (filename:10): Log with location\n",
                "100 ms: INFO in some logger: Named logger\n"):
            formatter.write(test_str)

        self.assertEqual(
            calls,
            [['0 ps: ', stream, 'bg', None],
             ['INFO', stream, 'rgbi', None],
             [': ', stream, None, None],
             ['Standard log', stream, None, None],

             ['100 ms: ', stream, 'bg', None],
             ['INFO', stream, 'rgbi', None],
             [' in ', stream, None, None],
             ['some logger', stream, 'bg', None],
             [' (', stream, None, None],
             ['filename:10', stream, 'rgb', None],
             [')', stream, None, None],
             [': ', stream, None, None],
             ['Log with location', stream, None, None],

             ['100 ms: ', stream, 'bg', None],
             ['INFO', stream, 'rgbi', None],
             [' in ', stream, None, None],
             ['some logger', stream, 'bg', None],
             [': ', stream, None, None],
             ['Named logger', stream, None, None]])

    def test_coloring_vhdl_assertions(self):

        # Store the printer write calls into a list
        printer_calls = []

        def printer_side_effect(text, output_file=None, fg=None, bg=None):
            """
            Side effect that print output to stdout
            """
            printer_calls.append([text, output_file, fg, bg])

        # We'll also store the stream write calls into a list
        stream_calls = []

        def stream_side_effect(out):
            """
            Side effect that print output to stdout
            """
            stream_calls.append(out)

        # Records will be colored by the printer. Mocking the write
        # command allows the need to check ASCII escape sequences
        printer = COLOR_PRINTER
        printer.write = printer_side_effect
        # Mock stream
        stream = mock.Mock(spec_set=MockStream)
        stream.configure_mock(isatty=True)
        stream.write.side_effect = stream_side_effect

        # Create a simple parser to the assertion format below
        def vhdl_report_parser_callback(line):
            """
            Custom VHDL assertion callback
            """
            for level in ('note', 'warning', 'error', 'failure'):
                if level in line:
                    return level
            return None

        formatter = log_color_overlay.LogColorOverlay(
            stream=stream,
            printer=printer,
            vhdl_report_parser_callback=vhdl_report_parser_callback)

        for test_str in (
                "severity level: note\n",     # Should be printed as info
                "severity level: warning\n",  # Should be printed as warning
                "severity level: error\n",    # Should be printed as error
                "severity level: failure\n",  # Should be printed as failure
                "no assertion\n"):
            formatter.write(test_str)

        # Check the assertions were identified and printed with the
        # correct colors
        self.assertEqual(
            printer_calls,
            [["severity level: note\n", stream, None, None],
             ["severity level: warning\n", stream, 'rgi', None],
             ["severity level: error\n", stream, 'ri', None],
             ["severity level: failure\n", stream, 'rgbi', 'r']])

        # Assertions that weren't identified by the callback should be
        # written directly to the stream
        self.assertEqual(stream_calls, ["no assertion\n"])

    def test_custom_colors_via_env_variable(self):
        with mock.patch.dict(os.environ,
                             {'VUNIT_LOG_COLORS': 'log_level[fg]=i;'
                                                  'log_source[bg]=r;'
                                                  'failure[bg]=None'}):
            self.assertEqual(
                log_color_overlay.get_colors_from_env(),
                {'log_level': {'fg': 'i', 'bg': None},
                 'log_source': {'fg': 'bg', 'bg': 'r'},
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
                log_color_overlay.get_colors_from_env()

    def test_get_env_color_fails_with_with_wrong_scope(self):
        with self.assertRaises(AssertionError):
            with mock.patch.dict(os.environ,
                                 {'VUNIT_LOG_COLORS': 'log_level[background]=i'}):
                log_color_overlay.get_colors_from_env()

    def test_get_env_color_fails_with_with_wrong_color(self):
        with self.assertRaises(AssertionError):
            with mock.patch.dict(os.environ,
                                 {'VUNIT_LOG_COLORS': 'log_level[fg]=foo'}):
                log_color_overlay.get_colors_from_env()


class MockStream(object):
    """
    Mocks a stream
    """
    write = None
    isatty = None
