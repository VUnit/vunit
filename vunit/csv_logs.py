# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides csv log functionality
"""

from csv import Sniffer, DictReader, DictWriter
from glob import glob
from pathlib import Path


class CsvLogs(object):
    # pylint: disable=missing-docstring

    def __init__(self, pattern="", field_names=None, encoding="iso-8859-1"):
        default_field_names = [
            "#",
            "Time",
            "Level",
            "File",
            "Line",
            "Source",
            "Message",
        ]
        self._field_names = default_field_names if field_names is None else field_names
        self._entries = []
        self._encoding = encoding
        self.add(pattern)

    def __iter__(self):
        return iter(self._entries)

    def add(self, pattern):
        # pylint: disable=missing-docstring
        for csv_file in [Path(p).resolve() for p in glob(pattern)]:
            with csv_file.open("r", encoding=self._encoding) as fread:
                sample = fread.readline()
                fread.seek(0)
                if sample:
                    dialect = Sniffer().sniff(sample)
                    self._entries += DictReader(fread, fieldnames=self._field_names, dialect=dialect)

        self._entries.sort(key=lambda dictionary: int(dictionary["#"]))

    def write(self, output_file):
        # pylint: disable=missing-docstring
        with Path(output_file).open("w", encoding=self._encoding) as fwrite:
            csv_writer = DictWriter(fwrite, delimiter=",", fieldnames=self._field_names, lineterminator="\n")
            csv_writer.writerow({name: name for name in self._field_names})
            csv_writer.writerows(self._entries)
