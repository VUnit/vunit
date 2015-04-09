# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides csv log functionality
"""

from csv import Sniffer, DictReader, DictWriter
from glob import glob
from os.path import abspath


class CsvLogs(object):
    # pylint: disable=missing-docstring

    def __init__(self, pattern='', field_names=None):
        default_field_names = ['#', 'Time', 'Level', 'File', 'Line', 'Source', 'Message']
        self._field_names = default_field_names if field_names is None else field_names
        self._entries = []
        self.add(pattern)

    def __iter__(self):
        return iter(self._entries)

    def add(self, pattern):
        # pylint: disable=missing-docstring
        for csv_file in [abspath(p) for p in glob(pattern)]:
            with open(csv_file, "r") as fread:
                sample = fread.readline()
                fread.seek(0)
                if len(sample) > 0:
                    dialect = Sniffer().sniff(sample)
                    self._entries += DictReader(fread, fieldnames=self._field_names, dialect=dialect)

        self._entries.sort(key=lambda dictionary: int(dictionary['#']))

    def write(self, output_file):
        # pylint: disable=missing-docstring
        with open(output_file, "w") as fwrite:
            csv_writer = DictWriter(fwrite, delimiter=',', fieldnames=self._field_names, lineterminator="\n")
            csv_writer.writerow({name: name for name in self._field_names})
            csv_writer.writerows(self._entries)
