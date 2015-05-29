# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains functionality to manage the configuration of tests
"""


import logging
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
        self._configs = {}
        self._plis = {}

    def set_generic(self, name, value, scope=create_scope()):
        """
        Set generic within scope
        """
        if scope not in self._generics:
            self._generics[scope] = {}
        self._generics[scope][name] = value

    def set_pli(self, value, scope=create_scope()):
        """
        Set pli within scope
        """
        self._plis[scope] = value

    def add_config(self, scope, name, generics, post_check=None):
        """
        Add a configuration for scope specifying the name of the
        configuration, its generic values as well as a post_check
        function to be run after the simulation
        """
        if scope not in self._configs:
            self._configs[scope] = {}
        self._configs[scope][name] = (generics, post_check)

    def get_configurations(self, scope):
        """
        Get all configurations for scope
        """
        global_generics = self._get_generics_for_scope(scope)
        pli = self._get_pli_for_scope(scope)
        configs_for_scope = self._get_configs_for_scope(scope)

        configs = []
        for config_name in sorted(configs_for_scope.keys()):
            cfg_generics, post_check = configs_for_scope[config_name]
            generics = global_generics.copy()
            generics.update(cfg_generics)
            configs.append(Configuration(config_name, generics, post_check, pli))

        if len(configs) == 0:
            configs = [Configuration("", global_generics.copy(), None, pli)]

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

    def _get_pli_for_scope(self, scope):
        """
        Get scope inferred pli, specific scope has precedence
        """
        plis = []
        for iter_scope in iter_scopes(scope):
            plis = self._plis.get(iter_scope, plis)
        return plis

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
        add(self._plis)
        return result


class Configuration(object):
    """
    Represents a configuration of a test bench
    """
    def __init__(self,
                 name="",
                 generics=None,
                 post_check=None,
                 pli=None):
        self.name = name
        self.generics = generics if generics is not None else {}
        self.post_check = post_check
        self.pli = [] if pli is None else pli

    def __eq__(self, other):
        return (self.name == other.name and
                self.generics == other.generics and
                self.post_check == other.post_check and
                self.pli == other.pli)

    def __repr__(self):
        return("Configuration(%r, %r, %r, %r)"
               % (self.name, self.generics, self.post_check, self.pli))


def is_within_scope(scope, other_scope):
    """
    Returns True if other_scope is strictly within scope
    """
    if len(other_scope) <= len(scope):
        return False
    return other_scope[:len(scope)] == scope
