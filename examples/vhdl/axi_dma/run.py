# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
AXI DMA
-------

Demonstrates the AXI read and write slave verification components as
well as the AXI-lite master verification component. An AXI DMA is
verified which uses an AXI master port to read and write data from
external memory. The AXI DMA also has a control register interface
via AXI-lite.
"""

from os import popen
from os.path import join, dirname
from vunit import VUnit
import inspect

vu = VUnit.from_argv(external={'string': True, 'integer': False})
vu.add_osvvm()
vu.add_verification_components()

src_path = join(dirname(__file__), "src")
ext_srcs = join(dirname(inspect.getfile(VUnit)), 'vhdl', 'data_types', 'src', 'external')

vu.add_library("axi_dma_lib").add_source_files(
    [join(src_path, "*.vhd"), join(src_path, "test", "*.vhd")]
)

c_obj = join(src_path, 'test', 'main.o')

print(popen(' '.join([
    'gcc -fPIC -rdynamic',
    '-I', ext_srcs,
    '-c', join(src_path, '**', 'main.c'),
    '-o', c_obj
])).read())

vu.set_sim_option("ghdl.elab_flags", [
    '-Wl,' + c_obj,
    '-Wl,-Wl,--version-script=' + join(ext_srcs, 'grt.ver')
])

vu.main()
