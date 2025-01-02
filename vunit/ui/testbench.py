# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class TestBench
"""

from fnmatch import fnmatch
from .common import lower_generics
from .test import Test


class TestBench(object):
    """
    User interface of a test bench.
    A test bench consists of one or more :class:`.Test` cases. Setting options for a test
    bench will apply that option to all test cases belonging to that test bench.
    """

    def __init__(self, test_bench, library):
        self._test_bench = test_bench
        self._library = library

    @property
    def name(self):
        """
        :returns: The entity or module name of the test bench
        """
        return self._test_bench.name

    @property
    def library(self):
        """
        :returns: The library that contains this test bench
        """
        return self._library

    def set_attribute(self, name, value):
        """
        Set a value of attribute within all |configurations| of this test bench or test cases within it

        :param name: The name of the attribute
        :param value: The value of the atrribute

        :example:

        .. code-block:: python

           test_bench.set_attribute(".foo", "bar")

        """
        self._test_bench.set_attribute(name, value)

    def set_generic(self, name, value):
        """
        Set a value of generic within all |configurations| of this test bench or test cases within it

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test_bench.set_generic("data_width", 16)

        """
        self._test_bench.set_generic(name.lower(), value)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within all |configurations| of this test bench or test cases within it

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test_bench.set_parameter("data_width", 16)

        """
        self._test_bench.set_generic(name, value)

    def set_vhdl_configuration_name(self, value: str):
        """
        Set VHDL configuration name of all
        |configurations| of this test bench or test cases within it

        :param value: The VHDL configuration name
        """
        self._test_bench.set_vhdl_configuration_name(value)

    def set_sim_option(self, name, value, overwrite=True):
        """
        Set simulation option within all |configurations| of this test bench or test cases within it

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param overwrite: To overwrite the option or append to the existing value

        :example:

        .. code-block:: python

           test_bench.set_sim_option("ghdl.a_flags", ["--no-vital-checks"])

        """
        self._test_bench.set_sim_option(name, value, overwrite)

    def set_pre_config(self, value):
        """
        Set :ref:`pre_config <pre_and_post_hooks>` function of all
        |configurations| of this test bench or test cases within it

        :param value: The pre_config function
        """
        self._test_bench.set_pre_config(value)

    def set_post_check(self, value):
        """
        Set :ref:`post_check <pre_and_post_hooks>` function of all
        |configurations| of this test bench or test cases within it

        :param value: The post_check function
        """
        self._test_bench.set_post_check(value)

    def add_config(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        name,
        generics=None,
        parameters=None,
        pre_config=None,
        post_check=None,
        sim_options=None,
        attributes=None,
        vhdl_configuration_name=None,
    ):
        """
        Add a configuration of this test bench or to all test cases within it by copying the default configuration.

        Multiple configuration may be added one after another.
        If no |configurations| are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set in addition to the default configuration
        :param parameters: A `dict` containing the parameters to be set in addition to the default configuration
        :param pre_config: A :ref:`callback function <pre_and_post_hooks>` to be called before test execution.
        :param post_check: A :ref:`callback function <pre_and_post_hooks>` to be called after test execution.
        :param sim_options: A `dict` containing the sim_options to be set in addition to the default configuration
        :param attributes: A `dict` containing the attributes to be set in addition to the default configuration
        :param vhdl_configuration_name: Name of VHDL configuration to use for the testbench entity, if any.

        :example:

        Given a test bench that by default gives rise to the test
        ``lib.test_bench`` and the following ``add_config`` calls:

        .. code-block:: python

           for data_width in range(14, 15+1):
               for sign in [False, True]:
                   test_bench.add_config(
                       name="data_width=%s,sign=%s" % (data_width, sign),
                       generics=dict(data_width=data_width, sign=sign))

        The following tests will be created:

        * ``lib.test_bench.data_width=14,sign=False``

        * ``lib.test_bench.data_width=14,sign=True``

        * ``lib.test_bench.data_width=15,sign=False``

        * ``lib.test_bench.data_width=15,sign=True``

        """
        generics = {} if generics is None else generics
        generics = lower_generics(generics)
        parameters = {} if parameters is None else parameters
        generics.update(parameters)
        attributes = {} if attributes is None else attributes
        self._test_bench.add_config(
            name=name,
            generics=generics,
            pre_config=pre_config,
            post_check=post_check,
            sim_options=sim_options,
            attributes=attributes,
            vhdl_configuration_name=vhdl_configuration_name,
        )

    def test(self, name):
        """
        Get a test within this test bench

        :param name: The name of the test
        :returns: A :class:`.Test` object
        """
        return Test(self._test_bench.get_test_case(name))

    def get_tests(self, pattern="*"):
        """
        Get a list of tests

        :param pattern: A wildcard pattern matching the test name
        :returns: A list of :class:`.Test` objects
        """
        results = []
        for test_case in self._test_bench.tests:
            if not fnmatch(test_case.name, pattern):
                continue

            results.append(Test(test_case))
        return results

    def scan_tests_from_file(self, file_name):
        """
        Scan tests from another file than the one containing the test
        bench.  Useful for when the top level test bench does not
        contain any tests.

        Such a structure is not the preferred way of doing things in
        VUnit but this method exists to accommodate legacy needs.

        :param file_name: The name of another file to scan for tests

        .. warning::
           The nested module containing the tests needs to be given
           the ``runner_cfg`` parameter or generic by the
           instantiating top level test bench. The nested module
           should not call its parameter or generic `runner_cfg` but
           rather `nested_runner_cfg` to avoid the VUnit test scanner
           detecting and running it as a test bench. In SystemVerilog
           the ``NESTED_TEST_SUITE`` macro should be used instead of
           the ``TEST_SUITE`` macro.
        """
        self._test_bench.scan_tests_from_file(file_name)
