#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Communication library
---------------------

Demonstrates the ``com`` message passing package which can be used
to communicate arbitrary objects between processes.  Further reading
can be found in the :ref:`com user guide <com_user_guide>`.
"""

from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_com()
VU.add_verification_components()
VU.add_osvvm()

ROOT = Path(__file__).parent

VU.add_library("lib").add_source_files(ROOT / "src" / "*.vhd")
VU.add_library("tb_lib").add_source_files(ROOT / "test" / "*.vhd")

VU.main()
