# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class Configuration
"""

from fnmatch import fnmatch
from collections import OrderedDict
from vunit.configuration import ConfigurationVisitor, DEFAULT_NAME


class Configuration(ConfigurationVisitor):
    """
    User interface for configuration sets.
    Provides methods for modifying existing configurations
    """

    def __init__(self, test_object, pattern):
        self._selected_cfg_dicts = []
        self._test_object = test_object
        for cfg_dict in test_object.get_configuration_dicts():
            selected_cfg_dict = OrderedDict()
            for name, cfg in cfg_dict.items():
                if fnmatch(name if name is not DEFAULT_NAME else "", pattern):
                    selected_cfg_dict[name] = cfg

            if selected_cfg_dict:
                self._selected_cfg_dicts.append(selected_cfg_dict)

    def get_configuration_dicts(self):
        return self._selected_cfg_dicts

    def add_config(self, *args, **kwargs):
        """
        This method is inherited from the superclass but not defined for this class. New
        configurations are added to :class:`.TestBench` or :class:`.Test` objects.
        """
        raise RuntimeError(
            f"{type(self)} do not allow addition of new configurations, only modification of existing ones."
        )
