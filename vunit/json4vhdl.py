# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
json4vhdl helper functions
"""

from pathlib import Path
from typing import Union
import json
from base64 import b16encode as b16enc


def encode_json(obj: object):
    """
    Convert object to stringified JSON

    :param obj: Object to stringify

    :example:

    .. code-block:: python

       stringified_generic = encode_json(generics)
    """
    return json.dumps(obj, separators=(",", ":"))


def read_json(filename: str):
    """
    Read a JSON file and return an object

    :param filename: The name of the file to read

    :example:

    .. code-block:: python

       generics = read_json(join(root, "src/test/data/data.json"))
    """
    with Path(filename).open("r", encoding="utf-8") as fptr:
        return json.loads(fptr.read())


def b16encode(data: Union[str, bytes]):
    """
    Encode a str|bytes using Base16 and return a str|bytes
    """
    if isinstance(data, str):
        return b16enc(bytes(data, "utf-8")).decode("utf-8")
    return b16encode(data)
