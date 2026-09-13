# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Fixture used to test that re-executing a Python file executes it again
(rather than being a no-op import).
"""

if "CALL_COUNT" not in globals():
    CALL_COUNT = 0
CALL_COUNT += 1


def get_call_count():
    return CALL_COUNT
