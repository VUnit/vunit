# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

from subprocess import check_call
from pathlib import Path
import sys
from sys import argv
from shutil import copyfile
from create_release_notes import create_release_notes
from docs_utils import examples, get_theme


DROOT = Path(__file__).parent.parent / 'docs'


def main():
    """
    Build documentation/website
    """
    create_release_notes()
    examples()
    copyfile(str(DROOT / '..' / 'LICENSE.rst'), str(DROOT / 'license.rst'))
    get_theme(
        DROOT,
        "https://codeload.github.com/buildthedocs/sphinx.theme/tar.gz/v1"
    )
    check_call(
        [
            sys.executable,
            "-m",
            "sphinx"
        ] + ([] if len(argv) < 2 else argv[2:]) + [
            "-TEWanb",
            "html",
            Path(__file__).parent.parent / "docs",
            argv[1],
        ]
    )


if __name__ == "__main__":
    main()
