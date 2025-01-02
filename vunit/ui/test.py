# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class Test
"""

from .common import lower_generics


class Test(object):
    """
    User interface of a single test case

    """

    def __init__(self, test_case):
        self._test_case = test_case

    @property
    def name(self):
        """
        :returns: the entity or module name of the test bench
        """
        return self._test_case.name

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
        Add a configuration to this test copying the default configuration.

        Multiple configuration may be added one after another.
        If no |configurations| are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set in addition to the default configuration.
        :param parameters: A `dict` containing the parameters to be set in addition to the default configuration.
        :param pre_config: A :ref:`callback function <pre_and_post_hooks>` to be called before test execution.
        :param post_check: A :ref:`callback function <pre_and_post_hooks>` to be called after test execution.
        :param sim_options: A `dict` containing the sim_options to be set in addition to the default configuration.
        :param attributes: A `dict` containing the attributes to be set in addition to the default configuration.
        :param vhdl_configuration_name: Name of VHDL configuration to use for the testbench entity, if any.

        :example:

        Given the ``lib.test_bench.test`` test and the following ``add_config`` calls:

        .. code-block:: python

           for data_width in range(14, 15+1):
               for sign in [False, True]:
                   test.add_config(
                       name="data_width=%s,sign=%s" % (data_width, sign),
                       generics=dict(data_width=data_width, sign=sign))

        The following tests will be created:

        * ``lib.test_bench.data_width=14,sign=False.test``

        * ``lib.test_bench.data_width=14,sign=True.test``

        * ``lib.test_bench.data_width=15,sign=False.test``

        * ``lib.test_bench.data_width=15,sign=True.test``

        """
        generics = {} if generics is None else generics
        generics = lower_generics(generics)
        parameters = {} if parameters is None else parameters
        generics.update(parameters)
        attributes = {} if attributes is None else attributes
        self._test_case.add_config(
            name=name,
            generics=generics,
            pre_config=pre_config,
            post_check=post_check,
            sim_options=sim_options,
            attributes=attributes,
            vhdl_configuration_name=vhdl_configuration_name,
        )

    def set_attribute(self, name, value):
        """
        Set a value of attribute within all |configurations| of this test

        :param name: The name of the attribute
        :param value: The value of the attribute

        :example:

        .. code-block:: python

           test.set_attribute(".foo", "bar")

        """
        self._test_case.set_attribute(name, value)

    def set_generic(self, name, value):
        """
        Set a value of generic within all |configurations| of this test

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test.set_generic("data_width", 16)

        """
        self._test_case.set_generic(name.lower(), value)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within all |configurations| of this test

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test.set_parameter("data_width", 16)

        """
        self._test_case.set_generic(name, value)

    def set_vhdl_configuration_name(self, value: str):
        """
        Set VHDL configuration name of all
        |configurations| of this test

        :param value: The VHDL configuration name
        """
        self._test_case.set_vhdl_configuration_name(value)

    def set_sim_option(self, name, value, overwrite=True):
        """
        Set simulation option within all |configurations| of this test

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param overwrite: To overwrite the option or append to the existing value

        :example:

        .. code-block:: python

           test.set_sim_option("ghdl.a_flags", ["--no-vital-checks"])

        """
        self._test_case.set_sim_option(name, value, overwrite)

    def set_pre_config(self, value):
        """
        Set :ref:`pre_config <pre_and_post_hooks>` function of all |configurations| of this test

        :param value: The pre_config function
        """
        self._test_case.set_pre_config(value)

    def set_post_check(self, value):
        """
        Set :ref:`post_check <pre_and_post_hooks>` function of all |configurations| of this test

        :param value: The post_check function
        """
        self._test_case.set_post_check(value)
