#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

from subprocess import check_call
from pathlib import Path
import sys
from sys import argv
from shutil import copyfile
from create_release_notes import create_release_notes


DROOT = Path(__file__).parent.parent / 'docs'


def get_theme(path: Path, url: str):
    """
    Check if the theme is available locally, retrieve it with curl and tar otherwise
    """
    tpath = path / "_theme"
    if not tpath.is_dir() or not (tpath / "theme.conf").is_file():
        if not tpath.is_dir():
            tpath.mkdir()
        zpath = path / "theme.tgz"
        if not zpath.is_file():
            check_call(["curl", "-fsSL", url, "-o", str(zpath)])
        tar_cmd = ["tar", "--strip-components=1", "-C", str(tpath), "-xvzf", str(zpath)]
        check_call(tar_cmd)


def main():
    """
    Build documentation/website
    """
    create_release_notes()
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
