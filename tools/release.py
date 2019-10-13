# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Create and validates new tagged release commits
The release process is described in the Contributing section of the web page
"""

from __future__ import print_function

import argparse
import json
from urllib.request import urlopen  # pylint: disable=no-name-in-module, import-error
import sys
from os.path import dirname, join, exists
import subprocess


def main():
    """
    Create a new tagged release commit
    """
    args = parse_args()

    if args.cmd == "create":
        version = args.version[0]
        major, minor, patch = parse_version(version)

        print("Attempting to create new release %s" % version)
        set_version(version)
        validate_new_release(version, pre_tag=True)
        make_release_commit(version)

        new_version = "%i.%i.%irc0" % (major, minor, patch + 1)
        set_version(new_version)
        make_next_pre_release_commit(new_version)

    elif args.cmd == "validate":
        version = get_local_version()
        validate_new_release(version, pre_tag=False)
        print("Release %s is validated for publishing" % version)


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
    run(["git", "add", release_note_file_name(version)])
    run(["git", "add", ABOUT_PY])
    run(["git", "commit", "-m", "Release %s" % version])
    run(["git", "tag", "v%s" % version, "-a", "-m", "release %s" % version])


def make_next_pre_release_commit(version):
    """
    Add release notes and make the release commit
    """
    run(["git", "add", ABOUT_PY])
    run(["git", "commit", "-m", "Start of next release candidate %s" % version])


def validate_new_release(version, pre_tag):
    """
    Check that a new release is valid or exit
    """

    release_note = release_note_file_name(version)
    if not exists(release_note):
        print(
            "Not releasing version %s since release note %s does not exist"
            % (version, release_note)
        )
        sys.exit(1)

    with open(release_note, "r") as fptr:
        if not fptr.read():
            print(
                "Not releasing version %s since release note %s is empty"
                % (version, release_note)
            )
            sys.exit(1)

    if pre_tag and check_tag(version):
        print(
            "Not creating new release %s since tag v%s already exist"
            % (version, version)
        )
        sys.exit(1)

    if not pre_tag and not check_tag(version):
        print(
            "Not releasing version %s since tag v%s does not exist" % (version, version)
        )
        sys.exit(1)

    with urlopen("https://pypi.python.org/pypi/vunit_hdl/json") as fptr:
        info = json.load(fptr)

    if version in info["releases"].keys():
        print("Version %s has already been released" % version)
        sys.exit(1)


def parse_version(version_str):
    """
    Create a 3-element tuple with the major,minor,patch version
    """
    return tuple([int(elem) for elem in version_str.split(".")])


def set_version(version):
    """
    Update vunit/about.py with correct version
    """

    with open(ABOUT_PY, "r") as fptr:
        content = fptr.read()

    print("Set local version to %s" % version)
    content = content.replace(
        'VERSION = "%s"' % get_local_version(), 'VERSION = "%s"' % version
    )

    with open(ABOUT_PY, "w") as fptr:
        fptr.write(content)

    assert get_local_version() == version


def release_note_file_name(version):
    return join(REPO_ROOT, "docs", "release_notes", version + ".rst")


def get_local_version():
    """
    Return the local python package version and check if corresponding release
    notes exist
    """
    version = (
        subprocess.check_output(
            [sys.executable, join(REPO_ROOT, "setup.py"), "--version"]
        )
        .decode()
        .strip()
    )

    return version


def check_tag(version):
    return "v" + version in set(
        subprocess.check_output(["git", "tag", "--list"]).decode().splitlines()
    )


def run(cmd):
    print(subprocess.list2cmdline(cmd))
    subprocess.check_call(cmd)


REPO_ROOT = join(dirname(__file__), "..")
ABOUT_PY = join(REPO_ROOT, "vunit", "about.py")


if __name__ == "__main__":
    main()
