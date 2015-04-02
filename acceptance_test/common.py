# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from xml.etree import ElementTree

import vunit.ostools as ostools
from vunit.modelsim_interface import ModelSimInterface


def has_modelsim():
    return ModelSimInterface.is_available()


def check_report(report_file, tests):
    tree = ElementTree.parse(report_file)
    root = tree.getroot()
    report = {}
    for test in root.iter("testcase"):
        status = "passed"

        if test.find("skipped") is not None:
            status = "skipped"

        if test.find("failure") is not None:
            status = "failed"
        report[test.attrib["name"]] = status

    for status, name in tests:
        assert report[name] == status

    num_tests = int(root.attrib["tests"])
    assert num_tests == len(tests)
