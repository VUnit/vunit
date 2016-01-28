# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
The command line interface of VUnit.

.. autoclass:: vunit.vunit_cli.VUnitCLI
   :members:

Adding custom command line arguments
------------------------------------
It is possible to add custom command line arguments to your ``run.py``
scripts using the :class:`.VUnitCLI` class.

A :class:`.VUnitCLI` object has a ``parser`` field which is an
:class:`ArgumentParser` object of the `argparse`_ library.

.. _argparse: https://docs.python.org/3/library/argparse.html

.. code-block:: python

   from vunit import VUnitCLI, VUnit

   # Add custom command line argument to standard CLI
   # Beware of conflicts with existing arguments
   cli = VUnitCLI()
   cli.parser.add_argument('--custom-arg', ...)
   args = cli.parse_args()

   # Create VUNit instance from custom arguments
   vu = VUnit.from_args(args=args)

   # Use args.custom_arg here ...
   print(args.custom_arg)

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
        """
        :param description: A custom short description of the command line tool
        """
        self.parser = self.create_argument_parser(description)

    def parse_args(self, argv=None):
        """
        Parse command line arguments

        :param argv: Use explicit argv instead of actual command line argument
        :returns: The parsed argument namespace object
        """
        return self.parser.parse_args(args=argv)

    @staticmethod
    def create_argument_parser(description=None):
        """
        Create the argument parser

        :param description: A custom short description of the command line tool
        :returns: The created :mod:`argparse` parser object
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

        parser.add_argument('--exit-0',
                            default=False,
                            action="store_true",
                            help=('Exit with code 0 even if a test failed. '
                                  'Still exits with code 1 on fatal errors such as compilation failure'))

        parser.add_argument('-v', '--verbose', action="store_true",
                            default=False,
                            help='Print test output immediately and not only when failure')

        parser.add_argument('--no-color', action='store_true',
                            default=False,
                            help='Do not color output')

        parser.add_argument('--log-level',
                            default="warning",
                            choices=["info", "error", "warning", "debug"])

        parser.add_argument('-p', '--num-threads', type=positive_int,
                            default=1,
                            help=('Number of tests to run in parallel. '
                                  'Test output is not continuously written in verbose mode with p > 1'))

        com = parser.add_argument_group("com", description="Flags specific to the com message passing package")
        com.add_argument('--use-debug-codecs', action='store_true',
                         default=False,
                         help='Run with debug features enabled')
        SimulatorFactory.add_arguments(parser)

        return parser


def positive_int(val):
    """
    ArgumentParse positive int check
    """
    try:
        ival = int(val)
        assert ival > 0
        return ival
    except (ValueError, AssertionError):
        raise argparse.ArgumentTypeError("'%s' is not a valid positive int" % val)
