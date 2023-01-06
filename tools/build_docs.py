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


REPO_ROOT = Path(__file__).parent.parent
DROOT = REPO_ROOT / 'docs'


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
            Version to set the section to for all newsfragments.
    """
    print(f"Adding newsfragment enteries to release notes for release {version}")
    if version:
        check_call(shlex.split(f"towncrier build --version {version} --yes"))
    else:
        # Produce draft version and write to file
        draft_file = DROOT / "_release_notes_draft.rst"
        with open(draft_file, "w") as f:
            check_call(shlex.split(f"towncrier build --version UNRELEASED --draft"), stdout=f)


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
    update_release_notes(version)
    copyfile(str(DROOT / '..' / 'LICENSE.rst'), str(DROOT / 'license.rst'))
    get_theme(
        DROOT,
        "https://codeload.github.com/buildthedocs/sphinx.theme/tar.gz/v1"
    )
    # Version is set for a release, so in that case this is not being called by tox so
    # we do not pass args. When not building for release, set release_notes_draft to
    # include the draft in the docs.
    check_call(
        [
            sys.executable,
            "-m",
            "sphinx"
        ] + ([] if len(sys.argv) < 2 or version else sys.argv[2:]) + (["-t", "release_notes_draft"] if version is None else []) + [
            "-TEWanb",
            "html",
            str(Path(__file__).parent.parent / "docs"),
            str(REPO_ROOT / "release" / "docs") if version else sys.argv[1],
        ]
    )


if __name__ == "__main__":
    main()
