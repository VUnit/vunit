# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class Results
"""


class Results(object):
    """
    Gives access to results after running tests.
    """

    def __init__(self, simulator_if):
        self._simulator_if = simulator_if

    def merge_coverage(self, file_name, args=None):
        """
        Create a merged coverage report from the individual coverage files

        :param file_name: The resulting coverage file name.
        :param args: The tool arguments for the merge command. Should be a list of strings.
        """

        self._simulator_if.merge_coverage(file_name=file_name, args=args)
