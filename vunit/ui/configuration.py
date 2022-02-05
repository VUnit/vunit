# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
UI classes ConfigurationList and Configuration
"""

from fnmatch import fnmatch
from collections import OrderedDict
from vunit.configuration import ConfigurationVisitor, DEFAULT_NAME


class Configuration(ConfigurationVisitor):
    """
    User interface for a configuration.

    Provides methods for modifying an existing configuration
    """

    def __init__(self, name, configuration):
        self._name = name
        self.configuration = configuration

    @property
    def name(self):
        """
        :returns: the name of the configuration
        """
        return self._name

    def get_configuration_dicts(self):
        return self.configuration

    def add_config(self, *args, **kwargs):
        """ """  # pylint: disable=empty-docstring
        raise NotImplementedError(
            f"{type(self)} do not allow addition of new configurations, only modification of existing ones."
        )

    def delete_config(self, *args, **kwargs):
        """ """  # pylint: disable=empty-docstring
        raise NotImplementedError(f"{type(self)} do not allow deletion of configurations, only modification.")


class ConfigurationList(ConfigurationVisitor):
    """
    User interface for a list of configurations.

    Provides methods for modifying existing configurations
    """

    def __init__(self, test_object, pattern):
        self._selected_config_dicts = []
        self._selected_configs = {}
        self._test_object = test_object

        for config_dict in test_object.get_configuration_dicts():
            selected_config_dict = OrderedDict()
            for name, config in config_dict.items():
                name_as_string = name if name is not DEFAULT_NAME else ""
                if fnmatch(name_as_string, pattern):
                    selected_config_dict[name_as_string] = config
                    if name_as_string not in self._selected_configs:
                        self._selected_configs[name_as_string] = []

                    self._selected_configs[name_as_string].append(OrderedDict({name_as_string: config}))

            if selected_config_dict:
                self._selected_config_dicts.append(selected_config_dict)

    def __iter__(self):
        """Iterate over :class:`.Configuration` objects."""
        for name, config in self._selected_configs.items():
            yield Configuration(name, config)

    def get_configuration_dicts(self):
        return self._selected_config_dicts

    def add_config(self, *args, **kwargs):
        """ """  # pylint: disable=empty-docstring
        raise NotImplementedError(
            f"{type(self)} do not allow addition of new configurations, only modification of existing ones."
        )

    def delete_config(self, *args, **kwargs):
        """ """  # pylint: disable=empty-docstring
        raise NotImplementedError(f"{type(self)} do not allow deletion of configurations, only modification.")
