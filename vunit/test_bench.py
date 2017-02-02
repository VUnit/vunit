# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Class to run a single test bench
"""

from os.path import join


class TestBench(object):  # pylint: disable=too-many-instance-attributes
    """
    Class to contain the context needed to run a specific test bench
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 simulator_if,
                 sim_config,
                 has_output_path=False):
        self._simulator_if = simulator_if
        self._sim_config = sim_config
        self._has_output_path = has_output_path

    def run(self, output_path, test_suite_name, extra_generics=None, elaborate_only=False):
        """
        Run test bench with output_path and extra_generics
        """
        generics = self._sim_config.generics.copy()

        if self._has_output_path:
            generics["output_path"] = '%s/' % output_path.replace("\\", "/")

        if extra_generics is not None:
            generics.update(extra_generics)

        self._sim_config.generics = generics

        return self._simulator_if.simulate(join(output_path, self._simulator_if.name),
                                           test_suite_name,
                                           self._sim_config,
                                           elaborate_only=elaborate_only)
