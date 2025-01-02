#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from itertools import product
from vunit import VUnit, VUnitCLI

cli = VUnitCLI()
cli.parser.add_argument(
    "--use-osvvm-log",
    action="store_true",
    default=False,
    help="Re-direct VUnit log output to OSVVM log handling",
)
cli.parser.add_argument(
    "--use-vunit-log",
    action="store_true",
    default=False,
    help="Re-direct OSVVM log output to VUnit log handling",
)
args = cli.parse_args()
if args.use_osvvm_log and args.use_vunit_log:
    raise RuntimeError("Only one of --use-osvvm-log and --use-vunit-log can be used at any time.")
args.clean = True
prj = VUnit.from_args(args=args)
root = Path(__file__).parent
if args.use_osvvm_log:
    prj.add_vhdl_builtins(use_external_log=Path(root / "osvvm_integration" / "vunit_to_osvvm_common_log_pkg-body.vhd"))
else:
    prj.add_vhdl_builtins()

lib = prj.add_library("lib")
lib.add_source_files(root / "*.vhd")
lib.test_bench("tb_example").set_generic("use_osvvm_log", args.use_osvvm_log)
lib.test_bench("tb_example").set_generic("use_vunit_log", args.use_vunit_log)

osvvm = prj.add_library("osvvm")
osvvm_files_to_compile = [
    "NamePkg.vhd",
    "OsvvmGlobalPkg.vhd",
    "TranscriptPkg.vhd",
    "TextUtilPkg.vhd",
    "OsvvmScriptSettingsPkg.vhd",
    "OsvvmScriptSettingsPkg_default.vhd",
]
for osvvm_file in osvvm_files_to_compile:
    osvvm.add_source_files(root / ".." / ".." / ".." / "vunit" / "vhdl" / "osvvm" / osvvm_file)

if args.use_vunit_log:
    osvvm.add_source_files(root / "osvvm_integration" / "osvvm_to_vunit_common_log_pkg.vhd")
    osvvm.add_source_files(root / "osvvm_integration" / "osvvm_to_vunit_common_log_pkg-body.vhd")
    osvvm.add_source_files(root / "osvvm_integration" / "AlertLogPkg.vhd")
else:
    osvvm.add_source_files(root / ".." / ".." / ".." / "vunit" / "vhdl" / "osvvm" / "AlertLogPkg.vhd")


prj.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
prj.main()
