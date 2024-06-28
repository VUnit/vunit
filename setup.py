# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

"""
PyPI setup script
"""

from glob import glob
from pathlib import Path
from logging import warning
from setuptools import setup

setup()

if len(glob(str(Path(__file__).parent / "vunit" / "vhdl" / "osvvm" / "*.vhd"))) == 0:
    warning(
        """
Found no OSVVM VHDL files. If you're installing from a Git repository and plan to use VUnit's integration
of OSVVM you should run

git submodule update --init --recursive

in your VUnit repository before running setup.py."""
    )
