# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

"""
PyPI setup script
"""

import os
import sys
from glob import glob
from logging import warning
from pathlib import Path
from typing import List, Optional

from setuptools import setup

# Ensure that the source tree is on the sys path
sys.path.insert(0, str(Path(__file__).parent.resolve()))


def osvvm_is_installed() -> bool:
    """
    Checks if OSVVM is installed within the VUnit directory structure
    """
    return len(glob(str(Path(__file__) / "vunit" / "vhdl" / "osvvm" / "*.vhd"))) != 0


def find_all_files(directory: str, endings: Optional[List[str]] = None) -> List[str]:
    """
    Recursively find all files within directory
    """
    result: List[str] = []
    for root, _, filenames in os.walk(directory):
        for filename in filenames:
            ending = os.path.splitext(filename)[-1]
            if endings is None or ending in endings:
                result.append(str(Path(root) / filename))
    return result


DATA_FILES: List[str] = []
DATA_FILES += find_all_files("vunit", endings=[".tcl"])
DATA_FILES += find_all_files(str(Path("vunit") / "vhdl"))
DATA_FILES += find_all_files(str(Path("vunit") / "verilog"), endings=[".v", ".sv", ".svh"])
DATA_FILES = [os.path.relpath(file_name, "vunit") for file_name in DATA_FILES]

setup(
    package_data={"vunit": DATA_FILES},
)

if not osvvm_is_installed():
    warning(
        """
Found no OSVVM VHDL files. If you're installing from a Git repository and plan to use VUnit's integration
of OSVVM you should run

git submodule update --init --recursive

in your VUnit repository before running setup.py."""
    )
