# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
MyPy check
"""

import unittest
import sys
from subprocess import check_call


class TestMyPy(unittest.TestCase):
    """
    Run MyPy static type analysis
    """

    @staticmethod
    def test_mypy():
        check_call([sys.executable, "-m", "mypy", "--namespace-packages", "vunit"])
