# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
A Python file with state of its own, used by tb_example.vhd to show the
difference between executing a file and importing it as a module.
"""

counter = 0


def bump():
    """
    Count one more call.
    """
    global counter  # pylint: disable=global-statement
    counter += 1
    return counter
