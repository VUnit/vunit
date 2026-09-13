# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Fixture used to test that a Python file executed by python_execute can import
a sibling module (from the same directory) without PYTHONPATH being set.
"""


def fir(x):
    return x + 1
