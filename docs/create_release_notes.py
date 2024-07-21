# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

"""
Create monolithic release notes file from several input files
"""

from pathlib import Path
from subprocess import check_call, check_output, CalledProcessError
from shutil import which
from datetime import datetime


def create_release_notes():
    """
    Create monolithic release notes file from several input files
    """
    docsroot = Path(__file__).parent
    root = docsroot.parent

    check_call(["towncrier", "build", "--keep"], cwd=root)

    # Get all releases defined by release note files
    releases = [
        Release(file_name, is_latest=idx == 0)
        for idx, file_name in enumerate(sorted((docsroot / "release_notes").glob("*.rst"), reverse=True))
    ]

    content = (
        "`Commits since last release "
        f"<https://github.com/VUnit/vunit/compare/v{releases[0].name!s}...master>`__"
        "\n\n"
    )

    for idx, release in enumerate(releases):
        title = f":vunit_commit:`{release.name!s} <v{release.name!s}>` - "
        if release.is_pre_release:
            title += "PRE-RELEASE - "
        title += f"{release.date.strftime('%Y-%m-%d')}"

        if idx == 0:
            title += " (latest)"
            content += ".. _release:latest:\n\n"

        content += (
            f".. _release:{release.name}:\n\n"
            f"{title}\n{'-' * len(title)}\n\n"
            f"`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/{release.name!s}/>`__"
        )

        if idx != len(releases) - 1:
            content += (
                f" | `Commits since previous release "
                f"<https://github.com/VUnit/vunit/compare/v{releases[idx + 1].name!s}...v{release.name!s}>`__"
            )

        content += f"\n\n.. include:: release_notes/{release.name}{release.suffix}\n\n\n"

    with open(str(docsroot / "release_notes.inc"), "w", encoding="utf-8") as fptr:
        fptr.write(content)


class Release(object):
    """
    A release object
    """

    def __init__(self, file_name, is_latest):
        self.suffix = file_name.suffix
        self.name = file_name.stem
        self.is_pre_release = "dev" in self.name
        tag = "v" + self.name.replace(".dev", "-dev.")

        git = which("git")
        if git is None:
            raise BaseException("'git' is required!")

        try:
            self._get_date(git, tag)
        except CalledProcessError:
            if not is_latest:
                raise
            print(f"Release tag {tag} not created yet, use HEAD for date")
            self._get_date(git, "HEAD")

    def _get_date(self, git, ref):
        """
        Get date
        """
        self.date = datetime.strptime(
            " ".join(check_output([git, "log", "-1", "--format=%ci", ref]).decode().strip().split(" ")[0:2]),
            "%Y-%m-%d %H:%M:%S",
        )
