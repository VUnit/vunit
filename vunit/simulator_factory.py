# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Create simulator instances
"""

from os.path import join, exists
import os
from vunit.modelsim_interface import ModelSimInterface
from vunit.activehdl_interface import ActiveHDLInterface
from vunit.rivierapro_interface import RivieraProInterface
from vunit.ghdl_interface import GHDLInterface


class SimulatorFactory(object):
    """
    Create simulator instances
    """

    @staticmethod
    def supported_simulators():
        """
        Return a list of supported simulator classes
        """
        return [ModelSimInterface,
                RivieraProInterface,
                ActiveHDLInterface,
                GHDLInterface]

    @classmethod
    def available_simulators(cls):
        """
        Return a list of available simulators
        """
        return [simulator_class
                for simulator_class in cls.supported_simulators()
                if simulator_class.is_available()]

    @classmethod
    def compile_options(cls):
        """
        Return all supported compile options
        """
        result = []
        for sim_class in cls.supported_simulators():
            for opt in sim_class.compile_options:
                assert opt.startswith(sim_class.name + ".")
                result.append(opt)
        return result

    @classmethod
    def sim_options(cls):
        """
        Return all supported sim options
        """
        result = []
        for sim_class in cls.supported_simulators():
            for opt in sim_class.sim_options:
                assert opt.startswith(sim_class.name + ".")
                result.append(opt)
        return result

    @classmethod
    def select_simulator(cls):
        """
        Select simulator class, either from VUNIT_SIMULATOR environment variable
        or the first available
        """
        environ_name = "VUNIT_SIMULATOR"

        available_simulators = cls.available_simulators()
        name_mapping = {simulator_class.name: simulator_class for simulator_class in cls.supported_simulators()}
        if len(available_simulators) == 0:
            return None

        if environ_name in os.environ:
            simulator_name = os.environ[environ_name]
            if simulator_name not in name_mapping:
                raise RuntimeError(
                    ("Simulator from " + environ_name + " environment variable %r is not supported. "
                     "Supported simulators are %r")
                    % (simulator_name, name_mapping.keys()))
            simulator_class = name_mapping[simulator_name]
        else:
            simulator_class = available_simulators[0]

        return simulator_class

    @classmethod
    def add_arguments(cls, parser, for_all_simulators=False):
        """
        Add command line arguments to parser
        """

        simulator = cls.select_simulator()

        if for_all_simulators or (simulator is not None and simulator.supports_gui_flag):
            parser.add_argument('-g', '--gui',
                                action="store_true",
                                default=False,
                                help=("Open test case(s) in simulator gui with top level pre loaded"))

        if for_all_simulators:
            for sim in cls.supported_simulators():
                sim.add_arguments(parser)
        elif simulator is not None:
            simulator.add_arguments(parser)

    def __init__(self, args):
        self._args = args
        self._output_path = args.output_path
        self._simulator_class = self.select_simulator()

    def package_users_depend_on_bodies(self):
        """
        Returns True when package users also depend on package bodies
        """
        if self._simulator_class is not None:
            return self._simulator_class.package_users_depend_on_bodies
        else:
            return False

    def supports_vhdl_2008_contexts(self):
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        if self._simulator_class is not None:
            return self._simulator_class.supports_vhdl_2008_contexts()
        else:
            return True

    @property
    def simulator_name(self):
        if self._simulator_class is None:
            return "none"
        else:
            return self._simulator_class.name

    @property
    def simulator_output_path(self):
        return join(self._output_path, self.simulator_name)

    def create(self):
        """
        Create new simulator instance
        """

        if self._simulator_class is None or not self._simulator_class.is_available():
            raise RuntimeError("No available simulator detected. "
                               "Simulator executables must be available in PATH environment variable.")

        if not exists(self.simulator_output_path):
            os.makedirs(self.simulator_output_path)

        return self._simulator_class.from_args(self.simulator_output_path,
                                               self._args)
