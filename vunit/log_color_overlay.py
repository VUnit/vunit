# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com
"""
Provides the formatter class for the 'verbose' log format
"""

import os
from sys import stdout
import logging
import re

from vunit.color_printer import COLOR_PRINTER

LOGGER = logging.getLogger(__name__)
_ENV_COLOR_DEF_RE = re.compile(r"(?P<key>\w+)\[(?P<scope>\w+)\]=(?P<color>\w+)(;|$)")


class LogColorOverlay(object):
    """
    Handles the 'verbose' log type, which means converting the CSV
    records into 'real' log records and adding colors if applicable
    """
    custom_levels = []  # Allows configuration of regexp
    _standard_levels = ['FAILURE', 'ERROR', 'WARNING', 'INFO', 'DEBUG', 'VERBOSE']
    _time_units = ['fs', 'ps', 'ns', 'us', 'ms', 'sec', 'min', 'hr']
    _vunit_log_pattern = re.compile(
        # A time specification is available in the verbose format but not in the level format
        '(?P<time_spec>' + r'(?P<log_time>\d+ (%s))' % '|'.join(_time_units) + ': ' + ')?' +
        # Standard or custom level
        r'(?P<log_level>%s)' % '|'.join(_standard_levels + custom_levels) +
        # A location specification is optional in the verbose format
        # and has a log source ID and/or a file location
        r'(?P<location_spec> in (?P<log_source>[^:(]+)?(\((?P<file_name>[^:]+):(?P<line_num>\d+)\))?' +
        r')?' +
        r': ' +
        r'(?P<message>.*)').search  # The message is the rest of the line

    def __init__(self, stream, printer=COLOR_PRINTER, vhdl_report_parser_callback=None):
        self._stream = stream
        self._printer = printer
        if vhdl_report_parser_callback is None:
            self._report_parser = lambda x: None
        else:
            self._report_parser = vhdl_report_parser_callback

    def _print(self, *args, **kwargs):
        self._printer.write(*args, **kwargs)

    def write(self, line):
        """
        Checks if the input string should be written as is or should
        be formatted and/or colored first
        """
        # Check if we find a VUnit log pattern
        vunit_log = self._vunit_log_pattern(line)
        if vunit_log is not None:
            # Just in the case we have buffered more stuff than the log
            # record, we'll write what came before, the log record, and
            # what came after
            self._stream.write(line[:vunit_log.start()])
            self._format_and_write(vunit_log)
            self._stream.write(line[vunit_log.end():])
            return

        vhdl_assertion = self._report_parser(line)

        if vhdl_assertion is not None:
            self._write_vhdl_assertion(str(vhdl_assertion).lower(), line)
        else:
            # No matches, just fallback to the default behaviour
            self._stream.write(line)

    def _write_vhdl_assertion(self, level, line):
        """
        Colorizes a VHDL assertion message based on the given level
        """
        # Translate severity levels from VHDL to the levels we have
        # defined
        if level == 'note':
            color = 'info'
        elif level == 'fatal':
            color = 'failure'
        else:
            color = level

        self._print(line, self._stream,
                    LOG_COLORS[color]['fg'],
                    LOG_COLORS[color]['bg'])

    def _format_and_write(self, match):
        """
        Writes the log line described by the info dict to the given stream.
        This method is intended to work on lines rather than on partial strings
        """
        info = match.groupdict()

        if info['log_time'] is not None:
            self._print(info['log_time'] + ': ', self._stream,
                        LOG_COLORS['log_time']['fg'],
                        LOG_COLORS['log_time']['bg'])

        self._print(info['log_level'].upper(), self._stream,
                    LOG_COLORS['log_level']['fg'],
                    LOG_COLORS['log_level']['bg'])

        if info['log_source'] is not None:
            self._print(' in ', self._stream)
            self._print(info['log_source'].strip(), self._stream,
                        LOG_COLORS['log_source']['fg'],
                        LOG_COLORS['log_source']['bg'])

        if info['file_name'] is not None and info['line_num'] is not None:
            self._print(' (', self._stream)
            self._print(info['file_name'] + ':' + info['line_num'],
                        self._stream,
                        LOG_COLORS['file_and_line']['fg'],
                        LOG_COLORS['file_and_line']['bg'])
            self._print(')', self._stream)

        self._print(': ', self._stream)

        log_level = info['log_level'].lower()
        self._print(info['message'], self._stream,
                    LOG_COLORS[log_level]['fg'],
                    LOG_COLORS[log_level]['bg'])

    def flush(self):
        self._stream.flush()

    def close(self):
        """
        This should not be called to close sys.stdout, so we'll log a
        warning if this happens
        """
        if self._stream is stdout:
            LOGGER.warning("Closing sys.stdout within LogColorOverlay!")
        self._stream.close()


def _is_entry_valid(entry):
    """
    Checks if the color configuration is valid
    """
    key, scope, color = entry['key'], entry['scope'], entry['color']

    if key not in ('log_time', 'log_level', 'log_source', 'file_and_line',
                   'verbose', 'debug', 'info', 'warning', 'error', 'failure',):
        return False

    if scope not in ('fg', 'bg'):
        return False

    if not (set(color).issubset('rgbi') or color == 'None'):
        return False

    return True


def get_colors_from_env():
    """
    Tries to get colors from VUNIT_LOG_COLORS env variable
    """
    # Copy the values from LOG_COLORS to change only the values
    # set by the user
    env_colors = LOG_COLORS.copy()

    for entry in _ENV_COLOR_DEF_RE.finditer(os.environ['VUNIT_LOG_COLORS']):
        entry_gd = entry.groupdict()
        assert _is_entry_valid(entry_gd), "Invalid color spec: '%s'" % entry.group()

        key, scope, color = entry_gd['key'], entry_gd['scope'], entry_gd['color']

        env_colors[key][scope] = color if color != "None" else None

    return env_colors

LOG_COLORS = {
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

if 'VUNIT_LOG_COLORS' in os.environ:
    LOG_COLORS.update(get_colors_from_env())
