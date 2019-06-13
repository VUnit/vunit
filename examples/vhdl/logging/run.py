# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Logging
-------

Demonstrates VUnit's support for logging.
"""

from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(dirname(__file__), "*.vhd"))

if __name__ == '__main__':
    ui.main()
