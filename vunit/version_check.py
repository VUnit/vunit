# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Check that the Python version used is supported by VUnit
"""

import sys

MAJOR = 3
MINOR = 6


def version_is_ok():
    """
    Returns true if version is high enough
    """
    version = (sys.version_info[0], sys.version_info[1])
    return version >= (3, 6)


if not version_is_ok():
    print(
        "Your Python version (%i.%i) is too old for VUnit. "
        "Please consider upgrading." % (sys.version_info[0], sys.version_info[1])
    )
    print("VUnit supports versions:")
    print(" - Python %i.%i or higher" % (MAJOR, MINOR))
    sys.exit(1)
