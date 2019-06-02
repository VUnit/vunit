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
    Return the local python package version and check if corresponding release
    notes exist
    """
    ver = check_output([
        sys.executable,
        join(dirname(__file__), "..", "setup.py"),
        "--version"
    ]).decode().strip()

    release_note = join(dirname(__file__), "..", "docs", "release_notes", ver + ".rst")
    if not exists(release_note):
        print("Not releasing version %s since release note %s does not exist" % (ver, release_note))
        exit(1)

    return ver


def check_tag(ver):
    return "v" + ver in set(check_output(["git", "tag", "--list"]).decode().splitlines())


def tag_release(ver):
    """
    Detects and tags a new release
    """
    if check_tag(ver):
        print("Not tagging release version %s since tag v%s already exists"
              % (ver, ver))
        exit(1)

    print("Tagging new release version: %s" % ver)

    check_output([
        'git',
        'tag',
        '"v' + ver + '" -a -m "Generated tag from TravisCI for release ' + ver + '"'
    ])


def check_release(ver):
    """
    Detects and releases a new tag
    """
    if not check_tag(ver):
        print("Not releasing version %s since tag v%s does not exist"
              % (ver, ver))
        exit(1)

    if ver.endswith("rc0"):
        print("Not releasing version %s since it ends with rc0" % ver)
        exit(1)

    with urlopen('https://pypi.python.org/pypi/vunit_hdl/json') as fptr:
        info = json.load(fptr)

    if ver in info["releases"].keys():
        print("Version %s has already been released" % ver)
        exit(1)

    check_output([
        'sed',
        '-i',
        '"s/PRE_RELEASE = True/PRE_RELEASE = False/"',
        'vunit/about.py'
    ])

    print("Releasing new version: %s" % ver)


if __name__ == "__main__":
    VER = get_local_version()

    if sys.argv[1] == 'check':
        check_release(VER)

    tag_release(VER)
