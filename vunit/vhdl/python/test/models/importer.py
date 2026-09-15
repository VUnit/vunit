# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Fixture used to test sibling import (from filters import fir  # type: ignore[import-not-found]) without
PYTHONPATH, and use of an inline-defined name (GAIN) from a file executed
later.
"""

from pathlib import Path

from filters import fir  # type: ignore[import-not-found]

MODEL_DIR = str(Path(__file__).parent)


def scaled(x):
    # GAIN is expected to already be defined in the namespace by an earlier
    # inline python_execute(source => ...) call.
    return fir(x) * GAIN  # noqa: F821


def dir_in_syspath():
    import sys

    return MODEL_DIR in sys.path
