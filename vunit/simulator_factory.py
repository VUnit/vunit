# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Create simulator instances
"""

from os.path import exists
import os
from vunit.modelsim_interface import ModelSimInterface
from vunit.activehdl_interface import ActiveHDLInterface
from vunit.rivierapro_interface import RivieraProInterface
from vunit.ghdl_interface import GHDLInterface
from vunit.incisive_interface import IncisiveInterface
from vunit.simulator_interface import (BooleanOption,
                                       ListOfStringOption,
                                       VHDLAssertLevelOption)


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
                GHDLInterface,
                IncisiveInterface]

    def _extract_compile_options(self):
        """
        Return all supported compile options
        """
        result = {}
        for sim_class in self.supported_simulators():
            for opt in sim_class.compile_options:
                assert hasattr(opt, "name")
                assert hasattr(opt, "validate")
                assert opt.name.startswith(sim_class.name + ".")
                assert opt.name not in result
                result[opt.name] = opt
        return result

    def _extract_sim_options(self):
        """
        Return all supported sim options
        """
        result = dict((opt.name, opt) for opt in
                      [VHDLAssertLevelOption(),
                       BooleanOption("disable_ieee_warnings"),
                       ListOfStringOption("pli")])

        for sim_class in self.supported_simulators():
            for opt in sim_class.sim_options:
                assert hasattr(opt, "name")
                assert hasattr(opt, "validate")
                assert opt.name.startswith(sim_class.name + ".")
                assert opt.name not in result
                result[opt.name] = opt

        return result

    def check_sim_option(self, name, value):
        """
        Check that sim_option has legal name and value
        """
        known_options = sorted(list(self._sim_options.keys()))

        if name not in self._sim_options:
            raise ValueError("Unknown sim_option %r, expected one of %r" %
                             (name, known_options))

        self._sim_options[name].validate(value)

    def check_compile_option_name(self, name):
        """
        Check that the compile option is valid
        """
        known_options = sorted(list(self._compile_options.keys()))
        if name not in known_options:
            raise ValueError("Unknown compile_option %r, expected one of %r" %
                             (name, known_options))

    def check_compile_option(self, name, value):
        """
        Check that the compile option is valid
        """
        self.check_compile_option_name(name)
        self._compile_options[name].validate(value)

    def _select_simulator(self):
        """
        Select simulator class, either from VUNIT_SIMULATOR environment variable
        or the first available
        """
        environ_name = "VUNIT_SIMULATOR"

        available_simulators = self.available_simulators()
        name_mapping = {simulator_class.name: simulator_class for simulator_class in self.supported_simulators()}
        if not available_simulators:
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

    def add_arguments(self, parser, for_all_simulators=False):
        """
        Add command line arguments to parser
        """

        if for_all_simulators or (self.has_simulator and self._simulator_class.supports_gui_flag):
            parser.add_argument('-g', '--gui',
                                action="store_true",
                                default=False,
                                help=("Open test case(s) in simulator gui with top level pre loaded"))

        if for_all_simulators:
            for sim in self.supported_simulators():
                sim.add_arguments(parser)
        elif self._simulator_class is not None:
            self._simulator_class.add_arguments(parser)

    def __init__(self):
        self._available_simulators = [simulator_class
                                      for simulator_class in self.supported_simulators()
                                      if simulator_class.is_available()]
        self._simulator_class = self._select_simulator()
        self._compile_options = self._extract_compile_options()
        self._sim_options = self._extract_sim_options()

    def available_simulators(self):
        """
        Return a list of available simulators
        """
        return self._available_simulators

    def package_users_depend_on_bodies(self):
        """
        Returns True when package users also depend on package bodies
        """
        if self._simulator_class is not None:
            return self._simulator_class.package_users_depend_on_bodies

        return False

    def supports_vhdl_2008_contexts(self):
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        if self._simulator_class is not None:
            return self._simulator_class.supports_vhdl_2008_contexts()

        return True

    def get_osvvm_coverage_api(self):
        """
        Returns simulator name when OSVVM coverage API is supported, None otherwise.
        """
        if self._simulator_class is not None:
            return self._simulator_class.get_osvvm_coverage_api()

        return None

    def supports_vhdl_package_generics(self):
        """
        Returns True when this simulator supports VHDL package generics
        """
        if self._simulator_class is not None:
            return self._simulator_class.supports_vhdl_package_generics()

        return False

    @property
    def has_simulator(self):
        return self._simulator_class is not None

    @property
    def simulator_name(self):
        """
        Return the name of the selected simulator or none
        """
        if self._simulator_class is None:
            return "none"

        return self._simulator_class.name

    def create(self, args, simulator_output_path):
        """
        Create new simulator instance
        """

        if not self.has_simulator:
            raise RuntimeError("No available simulator detected. "
                               "Simulator executables must be available in PATH environment variable.")

        if not exists(simulator_output_path):
            os.makedirs(simulator_output_path)

        simulator_if = self._simulator_class.from_args(simulator_output_path, args)
        simulator_if.set_output_path(simulator_output_path)
        return simulator_if


SIMULATOR_FACTORY = SimulatorFactory()
