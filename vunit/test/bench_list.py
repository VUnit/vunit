# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains classes to manage the creation of test benches and runnable test cases thereof
"""

import re
import logging
from collections import OrderedDict
from .list import TestList
from .bench import TestBench

LOGGER = logging.getLogger(__name__)


class TestBenchList(object):
    """
    A list of test benchs
    """

    def __init__(self, database=None):
        self._libraries = OrderedDict()
        self._database = database

    def add_from_source_file(self, source_file):
        """
        Scan test benches from the source file and add to test bench list
        """
        for design_unit in source_file.design_units:
            if design_unit.is_entity or design_unit.is_module:
                if tb_filter is None or tb_filter(design_unit):
                    if design_unit.is_module or design_unit.is_entity:
                        self._add_test_bench(TestBench(design_unit, self._database))

    def _add_test_bench(self, test_bench):
        """
        Add the test bench
        """
        if test_bench.library_name not in self._libraries:
            self._libraries[test_bench.library_name] = OrderedDict()
        self._libraries[test_bench.library_name][test_bench.name] = test_bench

    def get_test_bench(self, library_name, name):
        return self._libraries[library_name][name]

    def get_test_benches_in_library(self, library_name):
        return list(self._libraries.get(library_name, {}).values())

    def get_test_benches(self):
        """
        Get all test benches
        """
        result = []
        for test_benches in self._libraries.values():
            for test_bench in test_benches.values():
                result.append(test_bench)
        return result

    def create_tests(self, simulator_if, seed, elaborate_only):
        """
        Create all test cases from the test benches
        """
        test_list = TestList()
        for test_bench in self.get_test_benches():
            test_bench.create_tests(simulator_if, seed, elaborate_only, test_list)
        return test_list

    def warn_when_empty(self):
        """
        Log a warning when there are no test benches
        """
        if not self.get_test_benches():
            LOGGER.warning(
                "Found no test benches using current filter rule:\n%s",
                tb_filter.__doc__,
            )


TB_PATTERN = "^(tb_.*)|(.*_tb)$"
TB_RE = re.compile(TB_PATTERN, re.IGNORECASE)


def tb_filter(design_unit):
    """
    Filters entities and modules that have a runner_cfg generic/parameter

    Gives warning when design_unit matches tb_* or *_tb without having a runner_cfg
    Gives warning when a design_unit has  a runner_cfg but the name does not match tb_* or *_tb
    """
    # Above docstring can show up in ui.py warnings
    has_runner_cfg = "runner_cfg" in design_unit.generic_names
    has_tb_name = TB_RE.match(design_unit.name) is not None

    design_unit_type = "Entity" if design_unit.is_entity else "Module"
    generic_type = "generic" if design_unit.is_entity else "parameter"

    if (not has_runner_cfg) and has_tb_name:
        LOGGER.warning(
            "%s %s matches testbench name regex %s but has no %s runner_cfg and will therefore not be run.\n"
            "in file %s",
            design_unit_type,
            design_unit.name,
            TB_PATTERN,
            generic_type,
            design_unit.file_name,
        )

    elif has_runner_cfg and not has_tb_name:
        LOGGER.warning(
            "%s %s has runner_cfg %s but the file name and the %s name does not match regex %s\nin file %s",
            design_unit_type,
            design_unit.name,
            generic_type,
            design_unit_type.lower(),
            TB_PATTERN,
            design_unit.file_name,
        )

    return has_runner_cfg
