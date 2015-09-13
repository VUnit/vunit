# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Generic simulator interface
"""


class SimulatorInterface(object):
    """
    Generic simulator interface
    """

    @staticmethod
    def package_users_depend_on_bodies():
        """
        Returns True when package users also depend on package bodies with this simulator
        """
        return False
