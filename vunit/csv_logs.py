# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from csv import Sniffer, DictReader, DictWriter
from glob import glob
from os.path import abspath

class CsvLogs:
    def __init__(self, pattern='', field_names=None):
        self._field_names = ['#', 'Time', 'Level', 'File', 'Line', 'Source', 'Message'] if not field_names else field_names
        self._entries = []
        self.add(pattern)

    def __iter__(self):
        return iter(self._entries)
    
    def add(self, pattern):
        for csv_file in [abspath(p) for p in glob(pattern)]:
            with open(csv_file, "r") as f:
                sample = f.readline()
                f.seek(0)
                if len(sample) > 0:
                    dialect = Sniffer().sniff(sample)
                    self._entries += DictReader(f, fieldnames=self._field_names, dialect=dialect)                    
        
        self._entries.sort(key = lambda dictionary : int(dictionary['#']))
  
    def write(self, output_file):
        with open(output_file, "w") as f:
            csv_writer = DictWriter(f, delimiter=',', fieldnames=self._field_names, lineterminator="\n")
            csv_writer.writerow({f:f for f in self._field_names})
            csv_writer.writerows(self._entries)
