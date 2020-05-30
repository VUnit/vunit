# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class Entity
"""


class Entity(object):
    """
    User interface of an Entity
    """

    def __init__(self, library_name, entity_name, source_file):
        self._library_name = library_name
        self._entity_name = entity_name
        self._source_file = source_file

    @property
    def name(self):
        """
        :returns: The entity name
        """
        return self._entity_name

    @property
    def library(self):
        """
        :returns: The library that contains this entity
        """
        return self._library_name

    @property
    def source_file(self):
        """
        :returns: The source file that contains this entity
        """
        return self._source_file
