# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Create simulator instances
"""

import os
from .activehdl import ActiveHDLInterface
from .ghdl import GHDLInterface
from .incisive import IncisiveInterface
from .modelsim import ModelSimInterface
from .nvc import NVCInterface
from .rivierapro import RivieraProInterface
from . import BooleanOption, ListOfStringOption, VHDLAssertLevelOption, StringOption


class SimulatorFactory(object):
    """
    Create simulator instances
    """

    def supported_simulators(self):
        """
        Return a list of supported simulator classes, built-in ones first
        """
        return [
            ModelSimInterface,
            RivieraProInterface,
            ActiveHDLInterface,
            GHDLInterface,
            IncisiveInterface,
            NVCInterface,
        ] + self._extra_simulators

    def register_simulator(self, simulator_class):
        """
        Add a simulator class (a SimulatorInterface subclass) to the supported simulators.
        Used by packages declaring a simulator, see :ref:`vunit_packages`. Select it with VUNIT_SIMULATOR=<name>.
        """
        name = getattr(simulator_class, "name", None)
        if not name:
            raise ValueError(f"Simulator class {simulator_class!r} must define a non-empty 'name'")
        if name in [sim.name for sim in self.supported_simulators()]:
            raise ValueError(f"A simulator named {name!r} is already registered")

        self._extra_simulators.append(simulator_class)
        try:
            self._compile_options = self._extract_compile_options()
            self._sim_options = self._extract_sim_options()
        except AssertionError:
            self._extra_simulators.remove(simulator_class)
            raise ValueError(
                f"Simulator {name!r} has invalid options: each option needs name (prefixed {name + '.'!r}), "
                "validate, and must be unique"
            ) from None

    def _extract_compile_options(self):
        """
        Return all supported compile options
        """
        result = dict((opt.name, opt) for opt in [BooleanOption("enable_coverage")])
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
        result = dict(
            (opt.name, opt)
            for opt in [
                VHDLAssertLevelOption(),
                BooleanOption("disable_ieee_warnings"),
                BooleanOption("enable_coverage"),
                ListOfStringOption("pli"),
                StringOption("seed"),
            ]
        )

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
            raise ValueError(f"Unknown sim_option {name!r}, expected one of {known_options!r}")

        self._sim_options[name].validate(value)

    def check_compile_option_name(self, name):
        """
        Check that the compile option is valid
        """
        known_options = sorted(list(self._compile_options.keys()))
        if name not in known_options:
            raise ValueError(f"Unknown compile_option {name!r}, expected one of {known_options!r}")

    def check_compile_option(self, name, value):
        """
        Check that the compile option is valid
        """
        self.check_compile_option_name(name)
        self._compile_options[name].validate(value)

    def select_simulator(self):
        """
        Select simulator class, either from VUNIT_SIMULATOR environment variable
        or the first available
        """
        available_simulators = self._detect_available_simulators()
        name_mapping = {simulator_class.name: simulator_class for simulator_class in self.supported_simulators()}
        if not available_simulators:
            return None

        environ_name = "VUNIT_SIMULATOR"
        if environ_name in os.environ:
            simulator_name = os.environ[environ_name]
            if simulator_name not in name_mapping:
                raise RuntimeError(
                    (
                        "Simulator from " + environ_name + " environment variable %r is not supported. "
                        "Supported simulators are %r"
                    )
                    % (simulator_name, name_mapping.keys())
                )
            simulator_class = name_mapping[simulator_name]
        else:
            simulator_class = available_simulators[0]

        return simulator_class

    def add_arguments(self, parser):
        """
        Add command line arguments to parser
        """

        parser.add_argument(
            "-g",
            "--gui",
            action="store_true",
            default=False,
            help=("Open test case(s) in simulator gui with top level pre loaded"),
        )

        for sim in self.supported_simulators():
            sim.add_arguments(parser)

    def __init__(self):
        self._extra_simulators = []
        self._compile_options = self._extract_compile_options()
        self._sim_options = self._extract_sim_options()

    def _detect_available_simulators(self):
        """
        Detect available simulators and return a list
        """
        return [simulator_class for simulator_class in self.supported_simulators() if simulator_class.is_available()]

    @property
    def has_simulator(self):
        return bool(self._detect_available_simulators())


SIMULATOR_FACTORY = SimulatorFactory()
