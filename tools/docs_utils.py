# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Helper functions to generate examples.rst from docstrings in run.py files
"""

import sys
import inspect
from os.path import join, dirname, isdir
from os import listdir


ROOT = join(dirname(__file__), '..', 'docs')


def examples():
    """
    Traverses the examples directory and generates examples.rst with the docstrings
    """
    eg_path = join(ROOT, '..', 'examples')
    egs_fptr = open(join(ROOT, 'examples.rst'), "w+")
    egs_fptr.write('\n'.join([
        '.. _examples:\n',
        'Examples',
        '========',
        '\n'
    ]))
    for language, subdir in {'VHDL': 'vhdl', 'SystemVerilog': 'verilog'}.items():
        egs_fptr.write('\n'.join([
            language,
            '~~~~~~~~~~~~~~~~~~~~~~~',
            '\n'
        ]))
        for item in listdir(join(eg_path, subdir)):
            loc = join(eg_path, subdir, item)
            if isdir(loc):
                egs_fptr.write(_get_eg_doc(
                    loc,
                    'https://github.com/VUnit/vunit//tree/master/examples/' + item
                ))


def _get_eg_doc(location, ref):
    """
    Reads the docstring from a run.py file and rewrites the title to make it a ref
    """
    sys.path.append(location)
    import run  # pylint: disable=import-error
    vc_doc = inspect.getdoc(run)
    del sys.modules['run']
    sys.path.remove(location)
    doc = ''
    if vc_doc:
        title = '`%s <%s/>`_' % (vc_doc.split('---', 1)[0][0:-1], ref)
        doc = '\n'.join([
            title,
            '-' * len(title),
            vc_doc.split('---\n', 1)[1],
            '\n'
        ])
    return doc
