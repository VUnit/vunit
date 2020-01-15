# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
AXI DMA
-------

Demonstrates the AXI read and write slave verification components as
well as the AXI-lite master verification component. An AXI DMA is
verified which uses an AXI master port to read and write data from
external memory. The AXI DMA also has a control register interface
via AXI-lite.
"""

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_osvvm()
vu.add_verification_components()

src_path = Path(__file__).parent / "src"

vu.add_library("axi_dma_lib").add_source_files(
    [src_path / "*.vhd", src_path / "test" / "*.vhd"]
)

vu.main()
