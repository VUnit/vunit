# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Utility to stub ostools.py functionality
"""


class OstoolsStub(object):
    """
    Stub of a file system
    """
    def __init__(self):
        self._files = {}
        self._times = {}
        self._current_time = 0

    @property
    def file_names(self):
        """
        Return a list of all file names
        """
        return self._files.keys()

    def file_exists(self, file_name):
        return file_name in self._files

    def read_file(self, file_name):
        return self._files[file_name]

    def write_file(self, file_name, contents):
        """
        Write contents to file_name and update modification time
        """
        self._times[file_name] = self._current_time
        self._files[file_name] = contents

    def remove_file(self, file_name):
        del self._files[file_name]

    def get_modification_time(self, file_name):
        return self._times[file_name]

    def tick(self):
        self._current_time += 1

    def get_time(self):
        return self._current_time
