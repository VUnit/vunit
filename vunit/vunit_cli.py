# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Adding Custom Command Line Arguments
------------------------------------
It is possible to add custom command line arguments to your ``run.py``
scripts using the :class:`.VUnitCLI` class.

.. autoclass:: vunit.vunit_cli.VUnitCLI
   :members:

A :class:`.VUnitCLI` object has a ``parser`` field which is an
`ArgumentParser` object of the `argparse`_ library.

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
        self.parser = _create_argument_parser(description)

    def parse_args(self, argv=None):
        """
        Parse command line arguments

        :param argv: Use explicit argv instead of actual command line argument
        :returns: The parsed argument namespace object
        """
        return self.parser.parse_args(args=argv)


def _create_argument_parser(description=None, for_documentation=False):
    """
    Create the argument parser

    :param description: A custom short description of the command line tool
    :param for_documentation: When used for user guide documentation
    :returns: The created :mod:`argparse` parser object
    """
    description = 'VUnit command line tool.' if description is None else description

    if for_documentation:
        default_output_path = "./vunit_out"
    else:
        default_output_path = join(abspath(os.getcwd()), "vunit_out")

    parser = argparse.ArgumentParser(description=description)

    parser.add_argument('test_patterns', metavar='tests', nargs='*',
                        default='*',
                        help='Tests to run')

    parser.add_argument('-l', '--list', action='store_true',
                        default=False,
                        help='Only list all test cases')

    parser.add_argument('-f', '--files', action='store_true',
                        default=False,
                        help='Only list all files in compile order')

    parser.add_argument('--compile', action='store_true',
                        default=False,
                        help='Only compile project without running tests')

    parser.add_argument('-k', '--keep-compiling', action='store_true',
                        default=False,
                        help='Continue compiling even after errors only skipping files that depend on failed files')

    parser.add_argument('--elaborate', action='store_true',
                        default=False,
                        help='Only elaborate test benches without running')

    parser.add_argument('--clean', action='store_true',
                        default=False,
                        help='Remove output path first')

    parser.add_argument('-o', '--output-path',
                        default=default_output_path,
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
                        choices=["info", "error", "warning", "debug"],
                        help=("Log level of VUnit internal python logging. "
                              "Used for debugging"))

    parser.add_argument('-p', '--num-threads', type=positive_int,
                        default=1,
                        help=('Number of tests to run in parallel. '
                              'Test output is not continuously written in verbose mode with p > 1'))

    SimulatorFactory.add_arguments(parser,
                                   for_all_simulators=for_documentation)

    com = parser.add_argument_group("com", description="Flags specific to the com message passing package")
    com.add_argument('--use-debug-codecs', action='store_true',
                     default=False,
                     help='Run with debug features enabled')

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


def _parser_for_documentation():
    """
    Returns an argparse object used by sphinx for documentation in user_guide.rst
    """
    return _create_argument_parser(for_documentation=True)
