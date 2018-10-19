# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains Configuration class which contains configuration of a test run
"""

import logging
import inspect
from os.path import dirname
from copy import copy
from vunit.simulator_factory import SIMULATOR_FACTORY


LOGGER = logging.getLogger(__name__)

# Name of default configuration
DEFAULT_NAME = None


class Configuration(object):  # pylint: disable=too-many-instance-attributes
    """
    Represents a configuration of a test bench
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 name,
                 design_unit,
                 generics=None,
                 sim_options=None,
                 pre_config=None,
                 post_check=None):
        self.name = name
        self._design_unit = design_unit
        self.generics = {} if generics is None else generics
        self.sim_options = {} if sim_options is None else sim_options

        self.tb_path = dirname(design_unit.original_file_name)

        # Fill in tb_path generic with location of test bench
        if "tb_path" in design_unit.generic_names:
            self.generics["tb_path"] = '%s/' % self.tb_path.replace("\\", "/")

        self.pre_config = pre_config
        self.post_check = post_check

    def copy(self):
        return Configuration(name=self.name,
                             design_unit=self._design_unit,
                             generics=self.generics.copy(),
                             sim_options=self.sim_options.copy(),
                             pre_config=self.pre_config,
                             post_check=self.post_check)

    @property
    def is_default(self):
        return self.name is DEFAULT_NAME

    @property
    def generic_names(self):
        return self._design_unit.generic_names

    @property
    def entity_name(self):
        return self._design_unit.name

    @property
    def design_unit_name(self):
        return self._design_unit.name

    @property
    def library_name(self):
        return self._design_unit.library_name

    @property
    def architecture_name(self):  # pylint: disable=missing-docstring
        if self._design_unit.is_entity:
            return next(iter(self._design_unit.architecture_names))

        return None

    def set_generic(self, name, value):
        """
        Set generic
        """
        if name not in self._design_unit.generic_names:
            LOGGER.warning(
                "Generic '%s' set to value '%s' not found in %s '%s.%s'. Possible values are [%s]",
                name, value,
                "entity" if self._design_unit.is_entity else "module",
                self._design_unit.library_name, self._design_unit.name,
                ", ".join('%s' % gname for gname in self._design_unit.generic_names))
        else:
            self.generics[name] = value

    def set_sim_option(self, name, value):
        """
        Set sim option
        """
        SIMULATOR_FACTORY.check_sim_option(name, value)
        self.sim_options[name] = copy(value)

    @property
    def vhdl_assert_stop_level(self):
        """
        Return the VHDL assert stop level to use with the simulator
        """
        if "vhdl_assert_stop_level" in self.sim_options:
            level = self.sim_options.get("vhdl_assert_stop_level")
        else:
            level = "error"

        return level

    def call_pre_config(self, output_path, simulator_output_path):
        """
        Call pre_config if available. Setting optional output_path
        """
        if self.pre_config is None:
            return True

        args = inspect.getargspec(self.pre_config).args  # pylint: disable=deprecated-method

        kwargs = {"output_path": output_path,
                  "simulator_output_path": simulator_output_path}

        for argname in list(kwargs.keys()):
            if argname not in args:
                del kwargs[argname]

        return self.pre_config(**kwargs) is True

    def call_post_check(self, output_path, read_output):
        """
        Call post_check if available. Setting optional output_path
        """
        if self.post_check is None:
            return True

        args = inspect.getargspec(self.post_check).args  # pylint: disable=deprecated-method

        kwargs = {"output_path": lambda: output_path,
                  "output": read_output}

        for argname, provider in list(kwargs.items()):
            if argname not in args:
                del kwargs[argname]
            else:
                kwargs[argname] = provider()

        return self.post_check(**kwargs) is True


class ConfigurationVisitor(object):
    """
    An interface to visit simulation run configurations
    """

    def _check_enabled(self):
        pass

    @staticmethod
    def get_configuration_dicts():
        raise NotImplementedError

    def set_generic(self, name, value):
        """
        Set generic
        """
        self._check_enabled()
        for configs in self.get_configuration_dicts():
            for config in configs.values():
                config.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set sim option
        """
        self._check_enabled()
        for configs in self.get_configuration_dicts():
            for config in configs.values():
                config.set_sim_option(name, value)

    def set_pre_config(self, value):
        """
        Set pre_config function
        """
        self._check_enabled()
        for configs in self.get_configuration_dicts():
            for config in configs.values():
                config.pre_config = value

    def set_post_check(self, value):
        """
        Set post_check function
        """
        self._check_enabled()
        for configs in self.get_configuration_dicts():
            for config in configs.values():
                config.post_check = value

    def add_config(self, name, generics=None, pre_config=None, post_check=None, sim_options=None):
        """
        Add a configuration copying unset fields from the default configuration:
        """
        self._check_enabled()

        if name in (DEFAULT_NAME, '', u''):
            raise ValueError("Illegal configuration name %r. Must be non-empty string" % name)

        for configs in self.get_configuration_dicts():
            if name in configs:
                raise RuntimeError("Configuration name %s already defined" % name)

            # Copy default configuration
            config = configs[DEFAULT_NAME].copy()
            config.name = name

            if pre_config is not None:
                config.pre_config = pre_config

            if post_check is not None:
                config.post_check = post_check

            if generics is not None:
                config.generics.update(generics)

            if sim_options is not None:
                config.sim_options.update(sim_options)

            configs[config.name] = config
