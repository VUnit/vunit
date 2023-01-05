# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

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
    for idx, file_name in enumerate(sorted(glob(str(release_notes / "*.rst")), reverse=True)):
        releases.append(Release(file_name, is_latest=idx == 0))
    return releases


def create_release_notes():
    """
    Create monolithic release notes file from several input files
    """
    source_path = Path(__file__).parent.parent / "docs"

    releases = get_releases(source_path)
    latest_release = releases[0]

    with (source_path / "release_notes.rst").open("w", encoding="utf-8") as fptr:
        fptr.write(
            f"""
.. _release_notes:

Release notes
=============

.. NOTE:: For installation instructions read :ref:`this <installing>`.

`Commits since last release <https://github.com/VUnit/vunit/compare/{latest_release.tag!s}...master>`__

"""
        )

        fptr.write("\n\n")

        for idx, release in enumerate(releases):
            is_last = idx == len(releases) - 1

            if release.is_latest:
                fptr.write(".. _latest_release:\n\n")

            title = f":vunit_commit:`{release.name!s} <{release.tag!s}>` - {release.date.strftime('%Y-%m-%d')!s}"
            if release.is_latest:
                title += " (latest)"
            fptr.write(title + "\n")
            fptr.write("-" * len(title) + "\n\n")

            fptr.write(f"\n`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/{release.name!s}/>`__")

            if not is_last:
                fptr.write(
                    f" | `Commits since previous release "
                    f"<https://github.com/VUnit/vunit/compare/{releases[idx + 1].tag!s}...{release.tag!s}>`__"
                )

            fptr.write("\n\n")

            fptr.write(f".. include:: {relpath(release.file_name, source_path)!s}\n")


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
                print(f"Release tag {self.tag!s} not created yet, use HEAD for date")
                self.date = _get_date("HEAD")
            else:
                raise

        with Path(file_name).open("r", encoding="utf-8") as fptr:
            self.notes = fptr.read()


def _get_date(commit):
    """
    Get date
    """
    git = which("git")
    if git is None:
        raise BaseException("'git' is required!")
    date_str = check_output([git, "log", "-1", "--format=%ci", commit]).decode().strip()
    date_str = " ".join(date_str.split(" ")[0:2])
    return datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
