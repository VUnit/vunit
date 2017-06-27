# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
The main public Python interface of VUnit-Verilog.
"""

from vunit.ui import VUnit as VUnitVHDL


class VUnit(VUnitVHDL):
    """
    VUnit Verilog interface
    """

    def add_builtins(self):  # pylint: disable=arguments-differ
        """
        Add vunit Verilog builtin libraries
        """
        self._builtins.add_verilog_builtins()
