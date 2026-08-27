# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Removed functions.
"""

from typing import Union

_REMOVAL_NOTICE = """\
{function} has been removed. JSON-for-VHDL support is now provided through a separate package.

Install it with:

pip install vunit-json-for-vhdl

Then:

from vunit_json_for_vhdl import {function}
"""


def encode_json(obj: object):  # pylint: disable=unused-argument
    """
    Removed function.
    """
    function = "encode_json"
    raise RuntimeError(_REMOVAL_NOTICE.format(function=function))


def read_json(filename: str):  # pylint: disable=unused-argument
    """
    Removed function.
    """
    function = "read_json"
    raise RuntimeError(_REMOVAL_NOTICE.format(function=function))


def b16encode(data: Union[str, bytes]):  # pylint: disable=unused-argument
    """
    Removed function.
    """
    function = "b16encode"
    raise RuntimeError(_REMOVAL_NOTICE.format(function=function))
