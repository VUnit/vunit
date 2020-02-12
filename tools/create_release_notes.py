# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Create monolithic release notes file from several input files
"""

from pathlib import Path
from os.path import relpath
from glob import glob
from subprocess import check_output, CalledProcessError
from shutil import which
import datetime


def get_releases(source_path: Path):
    """
    Get all releases defined by release note files
    """
    release_notes = source_path / "release_notes"
    releases = []
    for idx, file_name in enumerate(
        sorted(glob(str(release_notes / "*.rst")), reverse=True)
    ):
        releases.append(Release(file_name, is_latest=idx == 0))
    return releases


def create_release_notes():
    """
    Create monolithic release notes file from several input files
    """
    source_path = Path(__file__).parent.parent / "docs"

    releases = get_releases(source_path)
    latest_release = releases[0]

    def banner(fptr):
        fptr.write("\n" + ("-" * 80) + "\n\n")

    with (source_path / "release_notes.rst").open("w") as fptr:
        fptr.write(
            """
.. _release_notes:

Release notes
=============

For installation instructions read :ref:`this <installing>`.

`Commits since last release <https://github.com/VUnit/vunit/compare/%s...master>`__

"""
            % latest_release.tag
        )

        banner(fptr)

        for idx, release in enumerate(releases):
            is_last = idx == len(releases) - 1

            if release.is_latest:
                fptr.write(".. _latest_release:\n\n")

            title = ":vunit_commit:`%s <%s>` - %s" % (
                release.name,
                release.tag,
                release.date.strftime("%Y-%m-%d"),
            )
            if release.is_latest:
                title += " (latest)"
            fptr.write(title + "\n")
            fptr.write("-" * len(title) + "\n\n")

            fptr.write(".. include:: %s\n" % relpath(release.file_name, source_path))

            fptr.write(
                "\n`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/%s/>`__\n"
                % release.name
            )

            if not is_last:
                fptr.write(
                    "\n`Commits since previous release <https://github.com/VUnit/vunit/compare/%s...%s>`__\n"
                    % (releases[idx + 1].tag, release.tag)
                )
                banner(fptr)


class Release(object):
    """
    A release object
    """

    def __init__(self, file_name, is_latest):
        self.file_name = file_name
        self.name = str(Path(file_name).with_suffix("").name)
        self.tag = "v" + self.name
        self.is_latest = is_latest

        try:
            self.date = _get_date(self.tag)

        except CalledProcessError:
            if self.is_latest:
                # Release tag for latest release not yet created, assume HEAD will become release
                print("Release tag %s not created yet, use HEAD for date" % self.tag)
                self.date = _get_date("HEAD")
            else:
                raise

        with open(file_name, "r") as fptr:
            self.notes = fptr.read()


def _get_date(commit):
    """
    Get date
    """
    date_str = (
        check_output([which("git"), "log", "-1", "--format=%ci", commit])
        .decode()
        .strip()
    )
    date_str = " ".join(date_str.split(" ")[0:2])
    return datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
