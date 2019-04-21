# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
External Buffer
---------------

`Interfacing with foreign languages (C) through VHPIDIRECT <https://ghdl.readthedocs.io/en/latest/using/Foreign.html>`_

An array of type ``uint8_t`` is allocated in a C application and some values
are written to the first ``1/3`` positions. Then, the VHDL simulation is
executed, where the (external) array/buffer is used.

In the VHDL testbenches, two vector pointers are created, each of them using
a different access mechanism (``extfunc`` or ``extacc``). One of them is used to copy
the first ``1/3`` elements to positions ``[1/3, 2/3)``, while incrementing each value
by one. The second one is used to copy elements from ``[1/3, 2/3)`` to ``[2/3, 3/3)``,
while incrementing each value by two.

When the simulation is finished, the C application checks whether data was successfully
copied/modified. The content of the buffer is printed both before and after the
simulation.
"""

from vunit import VUnit
from os import popen
from os.path import join, dirname

src_path = join(dirname(__file__), 'src')

c_obj = join(src_path, 'main.o')
# Compile C application to an object
print(popen(' '.join([
    'gcc', '-fPIC',
    '-c', join(src_path, 'main.c'),
    '-o', c_obj
])).read())

# Enable the external feature for strings
vu = VUnit.from_argv(vhdl_standard='2008', compile_builtins=False)
vu.add_builtins({'string': True})

lib = vu.add_library('lib')
lib.add_source_files(join(src_path, '*.vhd'))

# Add the C object to the elaboration of GHDL
vu.set_sim_option('ghdl.elab_flags', ['-Wl,' + c_obj])

vu.main()
