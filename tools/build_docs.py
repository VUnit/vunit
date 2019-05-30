# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

from subprocess import check_call
from os.path import join, dirname
import sys
from create_release_notes import create_release_notes


def main():
    """
    Build documentation/website
    """
    create_release_notes()
    check_call([sys.executable, "-m", "sphinx",
                "-T", "-E", "-W", "-a", "-n", "-b", "html",
                join(dirname(__file__), "..", "docs"), sys.argv[1]])


if __name__ == "__main__":
    main()
