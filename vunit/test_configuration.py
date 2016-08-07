# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains functionality to manage the configuration of tests
"""


import logging
from vunit.simulator_factory import SimulatorFactory
LOGGER = logging.getLogger(__name__)


def create_scope(*args):
    """
    Create a scope
    """
    return args


def iter_scopes(scope):
    """
    Iterate between all scopes from global scope down to to specific scope
    """
    for i in range(len(scope) + 1):
        yield scope[:i]


class TestConfiguration(object):
    """
    Maintain a global view of test configurations within different
    scopes.

    Global scope: create_scope()
    Library scope: create_scope("lib")
    Entity scope: create_scope("lib", "entity")
    Test case scope: create_scope("lib", "entity", "test case")

    Specific scopes have priority over general scopes in case of conflict
    """
    def __init__(self):
        self._generics = {}
        self._sim_options = {}
        self._configs = {}
        self._plis = {}
        self._disable_ieee_warnings = set()
        self._scan_tests_from_file = {}

    def scan_tests_from_file(self, scope, file_name):
        """
        Scan tests from another file than the default one
        """
        self._scan_tests_from_file[scope] = file_name

    def file_to_scan_for_tests(self, scope):
        """
        Return the file to scan for tests or None if not set
        """
        if scope in self._scan_tests_from_file:
            return self._scan_tests_from_file[scope]

    def set_generic(self, name, value, scope=create_scope()):
        """
        Set generic within scope
        """
        if scope not in self._generics:
            self._generics[scope] = {}
        self._generics[scope][name] = value

    # Deprecated aliases To be removed in a future release
    _alias = {"ghdl.flags": "ghdl.elab_flags"}

    def set_sim_option(self, name, value, scope=create_scope()):
        """
        Set sim option within scope
        """

        if name in self._alias:
            new_name = self._alias[name]
            LOGGER.warning("Deprecated sim_option %r use %r instead", name, new_name)
            name = new_name
            if name.startswith("vsim_extra_args"):
                value = value.split()

        known_options = SimulatorFactory.sim_options()
        if name not in known_options:
            LOGGER.error("Unknown sim_option %r, expected one of %r",
                         name, known_options)
            raise ValueError(name)

        if scope not in self._sim_options:
            self._sim_options[scope] = {}
        self._sim_options[scope][name] = value

    def set_pli(self, value, scope=create_scope()):
        """
        Set pli within scope
        """
        self._plis[scope] = value

    def disable_ieee_warnings(self, scope=create_scope()):
        """
        Disable ieee warnings within scope
        """
        self._disable_ieee_warnings.add(scope)

    def add_config(self,  # pylint: disable=too-many-arguments
                   scope, name="", generics=None, pre_config=None, post_check=None):
        """
        Add a configuration for scope specifying:
        - The name of the configuration
        - The generic values
        - A post_config function to be run before the simulation
        - A post_check function to be run after the simulation
        """
        generics = {} if generics is None else generics
        if scope not in self._configs:
            self._configs[scope] = {}
        self._configs[scope][name] = (generics, pre_config, post_check)

    def get_configurations(self, scope):
        """
        Get all configurations for scope
        """
        global_generics = self._get_generics_for_scope(scope)
        pli = self._get_pli_for_scope(scope)
        configs_for_scope = self._get_configs_for_scope(scope)
        sim_options_for_scope = self._get_sim_options_for_scope(scope)
        disable_ieee_warnings = self._ieee_warnings_disabled_in_scope(scope)

        configs = []
        for config_name in sorted(configs_for_scope.keys()):
            cfg_generics, pre_config, post_check = configs_for_scope[config_name]
            generics = global_generics.copy()
            generics.update(cfg_generics)
            configs.append(Configuration(name=config_name,
                                         sim_config=SimConfig(
                                             generics=generics,
                                             pli=pli,
                                             disable_ieee_warnings=disable_ieee_warnings,
                                             options=sim_options_for_scope.copy()),
                                         pre_config=pre_config,
                                         post_check=post_check))

        if len(configs) == 0:
            configs = [Configuration(name="",
                                     sim_config=SimConfig(
                                         generics=global_generics.copy(),
                                         pli=pli,
                                         disable_ieee_warnings=disable_ieee_warnings,
                                         options=sim_options_for_scope.copy()),
                                     pre_config=None,
                                     post_check=None)]

        return configs

    def _get_configurations_for_scope(self, scope):
        """
        Helper function to get all configurations for a scope
        """

    def _get_configs_for_scope(self, scope):
        """
        Return configs for scope, specific scope has precedence
        """
        configs = {}
        for iter_scope in iter_scopes(scope):
            configs = self._configs.get(iter_scope, configs)
        return configs

    def _get_generics_for_scope(self, scope):
        """
        Get scope inferred generics, specific scope has precedence
        """
        generics = {}
        for iter_scope in iter_scopes(scope):
            generics.update(self._generics.get(iter_scope, {}))
        return generics

    def _get_sim_options_for_scope(self, scope):
        """
        Get scope inferred sim_options, specific scope has precedence
        """
        sim_options = {}
        for iter_scope in iter_scopes(scope):
            sim_options.update(self._sim_options.get(iter_scope, {}))
        return sim_options

    def _get_pli_for_scope(self, scope):
        """
        Get scope inferred pli, specific scope has precedence
        """
        plis = []
        for iter_scope in iter_scopes(scope):
            plis = self._plis.get(iter_scope, plis)
        return plis

    def _ieee_warnings_disabled_in_scope(self, scope):
        """
        Return true if ieee warnings are disabled within scope
        """
        for iter_scope in iter_scopes(scope):
            if iter_scope in self._disable_ieee_warnings:
                return True
        return False

    def more_specific_configurations(self, scope):
        """
        Return scopes containing more specific configurations
        """
        # @TODO speedup
        result = []

        def add(scopes):
            for other_scope in scopes:
                if is_within_scope(scope, other_scope):
                    result.append(other_scope)

        add(self._generics)
        add(self._configs)
        add(self._sim_options)
        add(self._plis)
        add(self._disable_ieee_warnings)
        return result


class Configuration(object):
    """
    Represents a configuration of a test bench
    """
    def __init__(self,
                 name="",
                 sim_config=None,
                 pre_config=None,
                 post_check=None):
        self.name = name
        self.sim_config = sim_config if sim_config is not None else SimConfig()
        self.pre_config = pre_config
        self.post_check = post_check

    def __eq__(self, other):
        return (self.name == other.name and
                self.sim_config == other.sim_config and
                self.pre_config == other.pre_config and
                self.post_check == other.post_check)

    def __repr__(self):
        return("Configuration(%r, %r, %r, %r)"
               % (self.name, self.sim_config, self.pre_config, self.post_check))


class SimConfig(object):
    """
    Simulation related configuration
    """

    def __init__(self,  # pylint: disable=too-many-arguments
                 generics=None,
                 pli=None,
                 disable_ieee_warnings=False,
                 fail_on_warning=False,
                 options=None):
        self.generics = generics if generics is not None else {}
        self.pli = [] if pli is None else pli
        self.disable_ieee_warnings = disable_ieee_warnings
        self.fail_on_warning = fail_on_warning
        self.options = {} if options is None else options

    def __eq__(self, other):
        return (self.generics == other.generics and
                self.pli == other.pli and
                self.disable_ieee_warnings == other.disable_ieee_warnings and
                self.fail_on_warning == other.fail_on_warning and
                self.options == other.options)

    def __repr__(self):
        return("SimConfig(%r, %r, %r, %r, %r)"
               % (self.generics,
                  self.pli,
                  self.disable_ieee_warnings,
                  self.fail_on_warning,
                  self.options))


def is_within_scope(scope, other_scope):
    """
    Returns True if other_scope is strictly within scope
    """
    if len(other_scope) <= len(scope):
        return False
    return other_scope[:len(scope)] == scope
