# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Check
-----

Demonstrates the VUnit check library.
"""

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()

# Enable location preprocessing but exclude all but check_false to make the example less bloated
vu.enable_location_preprocessing(
    exclude_subprograms=[
        "debug",
        "info",
        "check",
        "check_failed",
        "check_true",
        "check_implication",
        "check_stable",
        "check_equal",
        "check_not_unknown",
        "check_zero_one_hot",
        "check_one_hot",
        "check_next",
        "check_sequence",
        "check_relation",
    ]
)

vu.enable_check_preprocessing()

vu.add_library("lib").add_source_files(Path(__file__).parent / "tb_example.vhd")

vu.main()
