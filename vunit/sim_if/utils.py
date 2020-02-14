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
    """
    Simple wrapper to read tcl files by name in the sim_if/tcl directory
    """
    return read_tcl(abspath(join(dirname(__file__), "tcl", filename)), **kwargs)


def read_tcl(filepath, **kwargs):
    """
    Reads the given tcl file, interpreting <<>> as a format string to
    replace with a python variable within kwargs.
    Returns the contents of the tcl file after formatting variables.
    """
    with open(filepath, "r") as tcl_file:
        contents = tcl_file.read()

    # Use <<>> as f string template characters
    # Escape actual tcl {}'s and convert to regular f string
    contents = contents.replace("{", "{{")
    contents = contents.replace("}", "}}")
    contents = contents.replace("<<", "{")
    contents = contents.replace(">>", "}")

    contents = fr"""{contents}"""

    # Evaluate as raw f string using caller's locals and globals.
    return contents.format(**kwargs)
