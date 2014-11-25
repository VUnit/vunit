# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from csv import Sniffer, DictReader, DictWriter
from io import open
from sys import version_info
from glob import glob
from os.path import abspath

class CsvLogs:
    def __init__(self, pattern = '', field_names = None):
        self._field_names = ['#', 'Time', 'Level', 'File', 'Line', 'Source', 'Message'] if not field_names else field_names
        self._read_mode = 'r' if version_info >= (3, 0) else 'rb'
        self._write_mode = 'w' if version_info >= (3, 0) else 'wb'
        self._newline = '' if version_info >= (3, 0) else None
        self._entries = []
        self.add(pattern)

    def __iter__(self):
        return iter(self._entries)
    
    def add(self, pattern):
        for csv_file in [abspath(p) for p in glob(pattern)]:
            with open(csv_file, self._read_mode, newline = self._newline) as f:
                sample = f.readline()
                f.seek(0)
                if len(sample) > 0:
                    dialect = Sniffer().sniff(sample)
                    self._entries += DictReader(f, fieldnames = self._field_names, dialect = dialect)
        
        self._entries.sort(key = lambda dictionary : int(dictionary['#']))
  
    def write(self, output_file):
        with open(output_file, self._write_mode, newline = self._newline) as f:
            csv_writer = DictWriter(f, delimiter=',', fieldnames = self._field_names)
            csv_writer.writerow({f:f for f in self._field_names})
            csv_writer.writerows(self._entries)
