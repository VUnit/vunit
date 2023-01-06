#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

import shlex
import sys

from pathlib import Path
from subprocess import check_call
from shutil import copyfile


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


def update_release_notes(version):
    """Gather newsfragments and add them to the release notes.

    Args:
        version (str):
            Version to set the section to for all newsfragments. Newsfragments will be
            added to the release notes and the now old newsfragments will be staged for
            removal.
    """
    print(f"Adding newsfragment enteries to release notes for release {version}")
    check_call(shlex.split("towncrier build --version {version} --yes"))


def main(version=None):
    """Build documentation/website.

    Args:
        version (str):
            Version to set the section to for all newsfragments. Newsfragments will be
            added to the release notes and the now old newsfragments will be staged for
            removal.

            .. important::
                Only set the version during a release, otherwise files will be
                forcefully removed and staged for commit. For testing changes, set this
                to ``None`` so that the documentation shows unreleased changes but does
                not trigger removal of newsfragments in the source tree.
    """
    if version:
        update_release_notes(version)
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
        ] + ([] if len(sys.argv) < 2 else sys.argv[2:]) + [
            "-TEWanb",
            "html",
            Path(__file__).parent.parent / "docs",
            sys.argv[1],
        ]
    )


if __name__ == "__main__":
    main()
