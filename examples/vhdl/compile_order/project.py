# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Project creation is separated such that it can be re-used
"""

from os.path import join, dirname
ROOT = dirname(__file__)


def create_project(ui):
    """
    Create the project
    """
    lib = ui.add_library("lib")
    lib.add_source_files(join(ROOT, "*.vhd"))
