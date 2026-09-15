# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Fixture used to test python_execute(file_name => ...): __file__ availability
during execution and the relative/absolute file name resolution.
"""

from pathlib import Path

# POSIX style, to compare with tb_path on all platforms
FILE_DURING_EXEC = Path(__file__).as_posix()
MODEL_DIR = Path(__file__).parent.as_posix()


def get_model_dir():
    return MODEL_DIR


def get_file_during_exec():
    return FILE_DURING_EXEC
