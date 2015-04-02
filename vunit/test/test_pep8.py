# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from subprocess import check_call
from os.path import dirname, join


class TestPep8(unittest.TestCase):
    def test_pep8(self):
        repo_root = join(dirname(__file__), "..", "..")
        check_call(["pep8",
                    "--show-source",
                    "--show-pep8",
                    "--max-line-length=120",
                    repo_root])
