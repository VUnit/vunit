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

from os.path import join, dirname
from vunit import VUnit

if __name__ == '__main__':
    ui = VUnit.from_argv()
    ui.add_osvvm()
    ui.add_verification_components()

    src_path = join(dirname(__file__), "src")

    axi_dma_lib = ui.add_library("axi_dma_lib")
    axi_dma_lib.add_source_files(join(src_path, "*.vhd"))
    axi_dma_lib.add_source_files(join(src_path, "test", "*.vhd"))

    ui.main()
