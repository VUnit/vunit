# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Public VUnit interface
"""

from pathlib import Path
import vunit.version_check
from vunit.ui import VUnit
from vunit.vunit_cli import VUnitCLI
from vunit.about import version, doc

# Repository root
ROOT = str(Path(__file__).parent.parent.resolve())

__version__ = version()
__doc__ = doc()  # pylint: disable=redefined-builtin
