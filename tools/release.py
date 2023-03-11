#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
Create and validates new tagged release commits
The release process is described in the Contributing section of the web page
"""

import argparse
import json
from urllib.request import urlopen  # pylint: disable=no-name-in-module, import-error
import sys
from pathlib import Path
import subprocess
from shutil import which


def main():
    """
    Create a new tagged release commit
    """
    args = parse_args()

    if args.cmd == "create":
        version = args.version[0]
        major, minor, patch = parse_version(version)

        print(f"Attempting to create new release {version!s}")
        set_version(version)
        validate_new_release(version, pre_tag=True)
        make_release_commit(version)

        new_version = f"{major:d}.{minor:d}.{patch + 1:d}-dev"
        set_version(new_version)
        make_next_pre_release_commit(new_version)

    elif args.cmd == "validate":
        version = get_local_version()
        validate_new_release(version, pre_tag=False)
        print(f"Release {version!s} is validated for publishing")


def parse_args():
    """
    Parse command line arguments
    """

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    create = subparsers.add_parser("create")
    create.add_argument("version", nargs=1, help="The version to release")
    create.set_defaults(cmd="create")

    validate = subparsers.add_parser("validate")
    validate.set_defaults(cmd="validate")

    return parser.parse_args()


def make_release_commit(version):
    """
    Add release notes and make the release commit
    """
    run(["git", "add", str(release_note_file_name(version))])
    run(["git", "add", str(ABOUT_PY)])
    run(["git", "commit", "-m", f"Release {version!s}"])
    run(["git", "tag", f"v{version!s}", "-a", "-m", f"release {version!s}"])


def make_next_pre_release_commit(version):
    """
    Add release notes and make the release commit
    """
    run(["git", "add", str(ABOUT_PY)])
    run(["git", "commit", "-m", f"Start of next release candidate {version!s}"])


def validate_new_release(version, pre_tag):
    """
    Check that a new release is valid or exit
    """

    release_note = release_note_file_name(version)
    if not release_note.exists():
        print(f"Not releasing version {version!s} since release note {release_note!s} does not exist")
        sys.exit(1)

    with release_note.open("r") as fptr:
        if not fptr.read():
            print(f"Not releasing version {version!s} since release note {release_note!s} is empty")
            sys.exit(1)

    if pre_tag and check_tag(version):
        print(f"Not creating new release {version!s} since tag v{version!s} already exist")
        sys.exit(1)

    if not pre_tag and not check_tag(version):
        print(f"Not releasing version {version!s} since tag v{version!s} does not exist")
        sys.exit(1)

    with urlopen("https://pypi.python.org/pypi/vunit_hdl/json") as fptr:
        info = json.load(fptr)

    if version in info["releases"].keys():
        print(f"Version {version!s} has already been released")
        sys.exit(1)


def parse_version(version_str):
    """
    Create a 3-element tuple with the major,minor,patch version
    """
    return tuple((int(elem) for elem in version_str.split(".")))


def set_version(version):
    """
    Update vunit/about.py with correct version
    """

    with ABOUT_PY.open("r") as fptr:
        content = fptr.read()

    print(f"Set local version to {version!s}")
    content = content.replace(f'VERSION = "{get_local_version()!s}"', f'VERSION = "{version!s}"')

    with ABOUT_PY.open("w", encoding="utf-8") as fptr:
        fptr.write(content)

    assert get_local_version() == version


def release_note_file_name(version) -> Path:
    return REPO_ROOT / "docs" / "release_notes" / (version + ".rst")


def get_local_version():
    """
    Return the local python package version and check if corresponding release
    notes exist
    """
    version = subprocess.check_output([sys.executable, str(REPO_ROOT / "setup.py"), "--version"]).decode().strip()

    return version


def check_tag(version):
    return "v" + version in set(subprocess.check_output([which("git"), "tag", "--list"]).decode().splitlines())


def run(cmd):
    print(subprocess.list2cmdline(cmd))
    subprocess.check_call(cmd)


REPO_ROOT = Path(__file__).parent.parent
ABOUT_PY = REPO_ROOT / "vunit" / "about.py"


if __name__ == "__main__":
    main()
