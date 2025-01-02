# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Common functions
"""

from .factory import SIMULATOR_FACTORY


def has_simulator():
    return SIMULATOR_FACTORY.has_simulator


def simulator_is(*names):
    """
    Check that current simulator is any of names
    """
    supported_names = [sim.name for sim in SIMULATOR_FACTORY.supported_simulators()]
    for name in names:
        assert name in supported_names
    return SIMULATOR_FACTORY.select_simulator().name in names


def simulator_check(func):
    """
    Check some method of the selected simulator
    """
    simif = SIMULATOR_FACTORY.select_simulator()
    if simif is None:
        return False
    return func(simif)
