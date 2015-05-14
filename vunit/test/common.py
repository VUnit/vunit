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
from vunit.ui import VUnit
from os import environ

SIMULATORS = [ModelSimInterface]


def _get_simulator_to_use():
    """
    Return the class of the simulator to use
    """
    key = "VUNIT_SIMULATOR"
    if key in environ:
        for sim in SIMULATORS:
            if sim.name == environ[key]:
                return sim
    else:
        return SIMULATORS[0]
    assert False


def has_simulator():
    return _get_simulator_to_use().is_available()


def simulator_is(*names):
    """
    Check that current simulator is any of names
    """
    simulator_names = [sim.name for sim in SIMULATORS]
    for name in names:
        assert name in simulator_names
    return _get_simulator_to_use().name in names


def create_vunit(output_path,  # pylint: disable=too-many-arguments
                 vhdl_standard='2008',
                 test_filter=None,
                 clean=False,
                 compile_builtins=True,
                 xunit_xml=None,
                 persistent_sim=False,
                 compile_only=False):
    """
    Create instance of VUnit public interface
    """
    return VUnit(clean=clean,
                 verbose=True,
                 test_filter=test_filter,
                 output_path=output_path,
                 vhdl_standard=vhdl_standard,
                 compile_builtins=compile_builtins,
                 xunit_xml=xunit_xml,
                 persistent_sim=persistent_sim,
                 simulator_name=_get_simulator_to_use().name,
                 compile_only=compile_only)


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
