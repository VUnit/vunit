# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Detects when a new release shall be made
"""

from __future__ import print_function

import json
from urllib.request import urlopen  # pylint: disable=no-name-in-module, import-error
import sys
from os.path import dirname, join, exists
from subprocess import check_output


def get_local_version():
    """
    Return the local python package version
    """
    setup_file = join(dirname(__file__), "..", "setup.py")
    return check_output([sys.executable, setup_file, "--version"]).decode().strip()


def get_git_tags():
    return set(check_output(["git", "tag", "--list"]).decode().splitlines())


def is_new_release(version):
    """
    Return True when a new release shall be made
    """

    release_note = join(dirname(__file__), "..", "docs", "release_notes", version + ".rst")
    if not exists(release_note):
        print("Not releasing version %s since release note %s does not exist" % (version, release_note))
        return False

    tags = get_git_tags()
    expected_tag = "v" + version
    if expected_tag in tags:
        print("Not releasing version %s since %s tag already exists"
              % (version, expected_tag))
        return False

    if version.endswith("rc0"):
        print("Not releasing version %s since it ends with rc0" % version)
        return False

    with urlopen('https://pypi.python.org/pypi/vunit_hdl/json') as fptr:
        info = json.load(fptr)

    if version in info["releases"].keys():
        print("Version %s has already been released" % version)
        return False

    print("Releasing new version: %s" % version)
    return True


def main():
    """
    Detects when a new release shall be made and writes True to output file
    """
    version = get_local_version()

    with open(sys.argv[1], "w") as fptr:
        fptr.write(version)

    with open(sys.argv[2], "w") as fptr:
        fptr.write(str(is_new_release(version)))


if __name__ == "__main__":
    main()
