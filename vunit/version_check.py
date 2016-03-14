# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Check that the Python version used is supported by VUnit
"""

from __future__ import print_function
import sys


def version_is_ok():
    """
    Returns true if version is 2.7 or higher or equal to 3.3
    """
    version = (sys.version_info[0],
               sys.version_info[1])
    return version == (2, 7) or version >= (3, 3)


if not version_is_ok():
    print("Your Python version (%i.%i) is too old for VUnit. "
          "Please consider upgrading." % (sys.version_info[0],
                                          sys.version_info[1]))
    print("VUnit supports versions:")
    print(" - Python 2.7")
    print(" - Python 3.3 or higher")
    exit(1)
