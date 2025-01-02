# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Common functions re-used between test cases
"""

from pathlib import Path
from xml.etree import ElementTree
import contextlib
import functools
import os
import shutil
import random


def check_report(report_file, tests=None):
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

    if tests is None:
        tests = []
        for name in report:
            expected_status = "failed" if "Expected to fail:" in name else "passed"
            tests.append((expected_status, name))

    for status, name in tests:
        if report[name] != status:
            raise AssertionError("Wrong status of %s got %s expected %s" % (name, report[name], status))

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
    os.environ.clear()
    os.environ.update(environ)
    try:
        yield
    finally:
        os.environ.clear()
        os.environ.update(old_environ)


@contextlib.contextmanager
def create_tempdir(path: Path = None):
    """
    Create a temporary directory that is removed after the unit test
    """

    if path is None:
        path = Path(__file__).parent / ("tempdir_%i" % random.randint(0, 2**64 - 1))

    if path.exists():
        shutil.rmtree(path)

    os.makedirs(str(path))

    try:
        yield path
    finally:
        shutil.rmtree(path)


def with_tempdir(func):
    """
    Decorator to provide test function with a temporary path that is
    removed after calling the function.

    The path is named the same as the function and its parent module
    """

    @functools.wraps(func)
    def new_function(*args, **kwargs):
        """
        Wrapper funciton that maintains temporary directory around nested
        function
        """
        path_name = Path(__file__).parent / (func.__module__ + "." + func.__name__)
        with create_tempdir(path_name) as path:
            return func(*args, tempdir=path, **kwargs)

    return new_function


def get_vhdl_test_bench(test_bench_name, tests=None, same_sim=False, test_attributes=None):
    """
    Create a valid VUnit test bench

    returns a string
    """

    if test_attributes is None:
        test_attributes = {}

    tests_contents = ""
    if tests is None:
        pass
    else:
        tests_contents = ""
        last_idx = len(tests)
        for idx, test_name in enumerate(tests):
            if idx == 0:
                tests_contents += "    if "
            else:
                tests_contents += "    elsif "

            tests_contents += 'run("%s") then\n' % test_name

            if test_name in test_attributes:
                for attr_name in test_attributes[test_name]:
                    tests_contents += "-- vunit: %s\n" % attr_name

            if idx == last_idx:
                tests_contents += "    endif;\n"

    if same_sim:
        contents = "-- vunit: run_all_in_same_sim\n"
    else:
        contents = "\n"

    contents += """\
library vunit_lib;
context vunit_lib.vunit_context;

entity {test_bench_name} is
  generic (runner_cfg : string);
end entity;

architecture a of {test_bench_name} is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    {tests_contents}
    test_runner_cleanup(runner);
  end process;
end architecture;
""".format(
        test_bench_name=test_bench_name, tests_contents=tests_contents
    )

    return contents


def create_vhdl_test_bench_file(test_bench_name, file_name, tests=None, same_sim=False, test_attributes=None):
    """
    Create a valid VUnit test bench and writes it to file_name
    """
    with Path(file_name).open("wb") as fptr:
        fptr.write(
            get_vhdl_test_bench(
                test_bench_name=test_bench_name,
                tests=tests,
                same_sim=same_sim,
                test_attributes=test_attributes,
            ).encode("utf-8")
        )
