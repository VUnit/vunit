# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains type defining VHDL standards and operations on them
"""

from functools import total_ordering


@total_ordering
class VHDLStandard(object):
    """
    VHDL standard object which encapsulates knowledge about VHDL standards
    """

    _STANDARDS = {"1993", "2002", "2008", "2019"}

    def __init__(self, standard_name):
        if standard_name in self._STANDARDS:
            self._standard = standard_name
        else:
            for standard in self._STANDARDS:
                if standard.endswith(standard_name) and len(standard_name) == 2:
                    self._standard = standard
                    break
            else:
                raise ValueError(f"Unknown standard '{standard_name!s}'")

    def __eq__(self, other):
        if isinstance(other, self.__class__):
            return self._standard == other._standard  # pylint: disable=protected-access
        return False

    def __lt__(self, other):
        return int(self._standard) < int(other._standard)  # pylint: disable=protected-access

    def __str__(self):
        if self == VHDL.STD_1993:
            # For backwards compatibility due to legacy reasons
            return "93"
        return self._standard

    def __repr__(self):
        return f"VHDLStandard({self._standard!r})"

    def __hash__(self):
        return hash(self._standard)

    @property
    def supports_context(self):
        return self >= VHDL.STD_2008

    @property
    def and_later(self):
        """
        Return a set including this standard and all later standards
        """
        return {standard for standard in VHDL.STANDARDS if standard >= self}

    @property
    def and_earlier(self):
        """
        Return a set including this standard and all earlier standards
        """
        return {standard for standard in VHDL.STANDARDS if standard <= self}


class VHDL(object):
    """
    Just a namespace for standards
    """

    STD_1993 = VHDLStandard("1993")
    STD_2002 = VHDLStandard("2002")
    STD_2008 = VHDLStandard("2008")
    STD_2019 = VHDLStandard("2019")
    STANDARDS = [STD_1993, STD_2002, STD_2008, STD_2019]

    @staticmethod
    def standard(name):
        return VHDLStandard(name)
