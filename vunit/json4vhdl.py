# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
json4vhdl helper functions
"""

import json


def encode_json(obj):
    """
    Convert object to stringified JSON

    :param obj: Object to stringify

    :example:

    .. code-block:: python

       stringified_generic = encode_json(generics)
    """
    return json.dumps(obj, separators=(',', ':'))


def read_json(filename):
    """
    Read a JSON file and return an object

    :param filename: The name of the file to read

    :example:

    .. code-block:: python

       generics = read_json(join(root, "src/test/data/data.json"))
    """
    return json.loads(open(filename, 'r').read())
