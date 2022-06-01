#!/usr/bin/env python3

import os, sys, site
sys.path.append(os.path.abspath("../../../../vunit.asicnet/"))
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_osvvm()
VU.add_verification_components()

ulib = VU.add_library("uni")
ulib.add_source_files("uni_records_pkg.vhd")

rlib = VU.add_library("special")
rlib.add_source_files("special_records_pkg.vhd")


tlib = VU.add_library("tb_work")
tlib.add_source_files("tb_testbench.vhd")


lib = VU.add_library("design_work")
lib.add_source_files("stim4testbench.vhd")
lib.add_source_files("special_storage.vhd")
lib.add_source_files("pf_dpsram_special.v", file_type= "verilog")


VU.main()
