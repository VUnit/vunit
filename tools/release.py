#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Create and validates new tagged release commits
The release process is described in the Contributing section of the web page
Note that the releases are tagged using Semantic Versioning which differs from
Python module versioning when creating pre-releases.
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
        major, minor, patch, development = parse_version(args.version[0])
        create_release(major, minor, patch, development)

    elif args.cmd == "validate":
        version = get_local_version()
        major, minor, patch, development = parse_version(version)
        validate_new_release(major, minor, patch, development, pre_tag=False)
        print(f"Release {version} is validated for publishing")

    elif args.cmd == "development":
        major, minor, patch, development = parse_version(get_local_version())
        create_release(major, minor, patch, development)


def to_python_version(major, minor, patch, development):
    """
    Create Python version string.
    """

    version = f"{major}.{minor}.{patch}"
    if development:
        version += f".dev{development}"

    return version


def to_semver_version(major, minor, patch, development):
    """
    Create SemVer version string.
    """

    version = f"{major}.{minor}.{patch}"
    if development:
        version += f"-dev.{development}"

    return version


def create_release(major, minor, patch, development):
    """
    Create release.
    """

    version = to_python_version(major, minor, patch, development)

    print(f"Attempting to create new release {version}")
    set_version(version)
    validate_new_release(major, minor, patch, development, pre_tag=True)
    make_release_commit(major, minor, patch, development)

    if development:
        new_version = to_python_version(major, minor, patch, development + 1)
    else:
        new_version = to_python_version(major, minor, patch + 1, 1)
    set_version(new_version)
    make_next_pre_release_commit(new_version)


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

    development = subparsers.add_parser("development")
    development.set_defaults(cmd="development")

    return parser.parse_args()


def make_release_commit(major, minor, patch, development):
    """
    Add release notes and make the release commit.

    Tags are named according to Semantic Versioning which means that
    a development version X.Y.Z.devN is tagged vX.Y.Z-dev.N
    """
    python_version = to_python_version(major, minor, patch, development)

    run(["git", "add", str(release_note_file_name(python_version))])
    run(["git", "add", str(ABOUT_PY)])
    run(["git", "commit", "-m", f"Release {python_version}"])

    semver_version = to_semver_version(major, minor, patch, development)
    run(["git", "tag", f"v{semver_version}", "-a", "-m", f"Release {python_version}"])


def make_next_pre_release_commit(version):
    """
    Add release notes and make the release commit
    """
    run(["git", "add", str(ABOUT_PY)])
    run(["git", "commit", "-m", f"Start of next release candidate {version!s}"])


def validate_new_release(major, minor, patch, development, pre_tag):
    """
    Check that a new release is valid or exit
    """
    python_version = to_python_version(major, minor, patch, development)
    semver_version = to_semver_version(major, minor, patch, development)

    release_note = release_note_file_name(python_version)
    if not release_note.exists():
        print(f"Not releasing version {python_version} since release note {release_note} does not exist")
        sys.exit(1)

    with release_note.open("r") as fptr:
        if not fptr.read():
            print(f"Not releasing version {python_version} since release note {release_note} is empty")
            sys.exit(1)

    if pre_tag and check_tag(semver_version):
        print(f"Not creating new release {python_version} since tag v{semver_version} already exist")
        sys.exit(1)

    if not pre_tag and not check_tag(semver_version):
        print(f"Not releasing version {python_version} since tag v{semver_version} does not exist")
        sys.exit(1)

    with urlopen("https://pypi.python.org/pypi/vunit_hdl/json") as fptr:
        info = json.load(fptr)

    if python_version in info["releases"].keys():
        print(f"Version {python_version} has already been released")
        sys.exit(1)


def parse_version(version_str):
    """
    Create a 4-element tuple with the major,minor,patch, development version
    """
    elements = version_str.split(".")
    version = [int(elem) for elem in elements[0:3]]
    if len(elements) == 4:
        assert elements[3].startswith("dev")
        development_version = int(elements[3][3:])
        assert development_version > 0
        version += [development_version]
    else:
        version += [None]

    return tuple(version)


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
