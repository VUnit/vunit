# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Handles Cadence Incisive .cds files
"""

from vunit.ostools import read_file, write_file
import re


class CDSFile(dict):
    """
    Handles Cadence Incisive .cds files

    Only cares about 'define' but other lines are kept intact
    """

    _re_define = re.compile(r"\s*define\s+([a-zA-Z0-9_]+)\s+(.*)(#|$)")

    @classmethod
    def parse(cls, file_name):
        """
        Parse file_name and create CDSFile instance
        """
        contents = read_file(file_name)

        other_lines = []
        defines = {}
        for line in contents.splitlines():
            match = cls._re_define.match(line)

            if match is None:
                other_lines.append(line)
            else:
                defines[match.group(1)] = match.group(2)
        return cls(defines, other_lines)

    def __init__(self, defines, other_lines):
        dict.__init__(self, defines)
        self._other_lines = other_lines

    def write(self, file_name):
        """
        Write cds file to file named 'file_name'
        """
        contents = "\n".join(self._other_lines +
                             ["define %s %s" % item
                              for item in sorted(self.items())]) + "\n"
        write_file(file_name, contents)
