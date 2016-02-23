# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Common functions re-used between test cases
"""


from xml.etree import ElementTree
import contextlib
import os
from vunit.simulator_factory import SimulatorFactory


def has_simulator():
    return SimulatorFactory.select_simulator().is_available()


def simulator_is(*names):
    """
    Check that current simulator is any of names
    """
    supported_names = [sim.name for sim in SimulatorFactory.supported_simulators()]
    for name in names:
        assert name in supported_names
    return SimulatorFactory.select_simulator().name in names


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
        report[test.attrib["classname"] + "." + test.attrib["name"]] = status

    for status, name in tests:
        if report[name] != status:
            raise AssertionError("Wrong status of %s got %s expected %s" %
                                 (name, report[name], status))

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


@contextlib.contextmanager
def set_env(**environ):
    """
    Temporarily set the process environment variables.

    >>> with set_env(PLUGINS_DIR=u'test/plugins'):
    ...   "PLUGINS_DIR" in os.environ
    True

    >>> "PLUGINS_DIR" in os.environ
    False

    :type environ: dict[str, unicode]
    :param environ: Environment variables to set
    """
    old_environ = dict(os.environ)
    os.environ.update(environ)
    try:
        yield
    finally:
        os.environ.clear()
        os.environ.update(old_environ)
