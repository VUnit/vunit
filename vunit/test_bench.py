# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Class to run a single test bench
"""


class TestBench:
    """
    Class to contain the context needed to run a specific test bench
    """
    def __init__(self,
                 simulator_if,
                 library_name,
                 entity_name,
                 architecture_name=None,
                 generics=None,
                 has_output_path=False,
                 fail_on_warning=False,
                 pli=None,
                 elaborate_only=False):
        self._simulator_if = simulator_if
        self._library_name = library_name
        self._entity_name = entity_name
        self._generics = {} if generics is None else generics
        self._architecture_name = architecture_name
        self._has_output_path = has_output_path
        self._fail_on_warning = fail_on_warning
        self._pli = pli
        self._elaborate_only = elaborate_only

    def run(self, output_path, extra_generics=None):
        """
        Run test bench with output_path and extra_generics
        """
        generics = self._generics.copy()

        if self._has_output_path:
            generics["output_path"] = '%s/' % output_path.replace("\\", "/")

        if extra_generics is not None:
            generics.update(extra_generics)

        return self._simulator_if.simulate(output_path,
                                           self._library_name,
                                           self._entity_name,
                                           self._architecture_name,
                                           generics,
                                           fail_on_warning=self._fail_on_warning,
                                           pli=self._pli,
                                           load_only=self._elaborate_only)
