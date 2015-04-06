# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from subprocess import check_call
from vunit import ROOT
from os.path import join, dirname


class TestPylint(unittest.TestCase):
    def test_pylint(self):
        check_call(["pylint", "-E",
                    "--rcfile=" + join(dirname(__file__), "pylintrc"),
                    join(ROOT, "vunit")])
