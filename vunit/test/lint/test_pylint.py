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
    @staticmethod
    def test_pylint():
        check_call(["pylint",
                    "--disable=missing-docstring",
                    "--disable=too-few-public-methods",
                    "--disable=too-many-public-methods",
                    "--disable=too-many-instance-attributes",
                    "--disable=too-many-arguments",
                    "--disable=relative-import",
                    "--disable=old-style-class",  # Not a problem for Python3
                    "--disable=protected-access",
                    "--disable=locally-disabled",
                    "--disable=interface-not-implemented",
                    "--disable=duplicate-code",
                    "--rcfile=" + join(dirname(__file__), "pylintrc"),
                    join(ROOT, "vunit")])
