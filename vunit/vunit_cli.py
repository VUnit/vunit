# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
The command line interface of VUnit.
"""

import argparse
from os.path import join, abspath
import os
from vunit.simulator_factory import SimulatorFactory


class VUnitCLI(object):
    """
    VUnit command line interface
    """

    def __init__(self, description=None):
        self.parser = self.create_argument_parser(description)

    def parse_args(self, argv=None):
        """
        Parse arguments from 'argv' if not None instead of sys.argv
        """
        return self.parser.parse_args(args=argv)

    @staticmethod
    def create_argument_parser(description=None):
        """
        Create the argument parser
        """
        description = 'VUnit command line tool.' if description is None else description

        parser = argparse.ArgumentParser(description=description)

        parser.add_argument('test_patterns', metavar='tests', nargs='*',
                            default='*',
                            help='Tests to run')

        parser.add_argument('-l', '--list', action='store_true',
                            default=False,
                            help='Only list all test cases')

        parser.add_argument('--compile', action='store_true',
                            default=False,
                            help='Only compile project without running tests')

        parser.add_argument('--elaborate', action='store_true',
                            default=False,
                            help='Only elaborate test benches without running')

        parser.add_argument('--clean', action='store_true',
                            default=False,
                            help='Remove output path first')

        parser.add_argument('-o', '--output-path',
                            default=join(abspath(os.getcwd()), "vunit_out"),
                            help='Output path for compilation and simulation artifacts')

        parser.add_argument('-x', '--xunit-xml',
                            default=None,
                            help='Xunit test report .xml file')

        parser.add_argument('-v', '--verbose', action="store_true",
                            default=False,
                            help='Print test output immediately and not only when failure')

        parser.add_argument('--no-color', action='store_true',
                            default=False,
                            help='Do not color output')

        parser.add_argument('--log-level',
                            default="warning",
                            choices=["info", "error", "warning", "debug"])

        com = parser.add_argument_group("com", description="Flags specific to the com message passing package")
        com.add_argument('--use-debug-codecs', action='store_true',
                         default=False,
                         help='Run with debug features enabled')
        SimulatorFactory.add_arguments(parser)

        return parser
