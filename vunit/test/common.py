# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Common functions re-used between test cases
"""


from xml.etree import ElementTree
from vunit.modelsim_interface import ModelSimInterface


def has_modelsim():
    return ModelSimInterface.is_available()


def check_report(report_file, tests):
    """
    Check an XML report_file for the exact occurrence of specific test results
    """
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


def assert_exit(function, code=0):
    """
    Assert that 'function' performs SystemExit with code
    """
    try:
        function()
    except SystemExit as ex:
        assert ex.code == code
    else:
        assert False
