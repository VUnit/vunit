# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Wrapper arround mock to handle Python 3.x and 2.7
"""


try:
    # Python 3.x (builtin)
    import unittest.mock as mock  # pylint: disable=import-error, no-name-in-module, unused-import
except ImportError:
    # Python 2.7 (needs separate install)
    import mock as mock  # pylint: disable=import-error, unused-import
