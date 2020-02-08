# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Shared utils functions between sim_if modules
"""

from os.path import join, dirname, abspath


def read_sim_if_tcl(filename, **kwargs):
    return read_tcl(abspath(join(dirname(__file__), "tcl", filename)), **kwargs)


def read_tcl(filepath, **kwargs):
    with open(filepath, "r") as f:
        contents = f.read()

    # Use <<>> as f string template characters
    # Escape actual tcl {}'s and convert to regular f string
    contents = contents.replace("{", "{{")
    contents = contents.replace("}", "}}")
    contents = contents.replace("<<", "{")
    contents = contents.replace(">>", "}")

    contents = fr"""{contents}"""

    # Evaluate as raw f string using caller's locals and globals.
    return contents.format(**kwargs)
