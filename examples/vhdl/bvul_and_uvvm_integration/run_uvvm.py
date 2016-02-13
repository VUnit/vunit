# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname

# Make vunit python module importable. Can be removed if vunit is in your PYTHONPATH
# environment variable
import sys
path_to_vunit = join(dirname(__file__), '..', '..', '..')
sys.path.append(path_to_vunit)
#  -------

from vunit import VUnit, VUnitCLI

root = dirname(__file__)

# These lines add the option to specify the UVVM Utility Library root directory
# from the command line (python run.py -b <path to my UVVM root>). They
# can be replaced by a single line, ui = VUnit.from_argv(), if you assign the root
# directory to the uvvm_root variable directly
cli = VUnitCLI()
cli.parser.add_argument('-u', '--uvvm-root',
                        required=True,
                        help='UVVM Utility Library root directory')
args = cli.parse_args()
ui = VUnit.from_args(args)
# ------

# Create VHDL libraries and add the related UVVM files to these
uvvm_root = args.uvvm_root

uvvm_lib = ui.add_library('uvvm_util')
uvvm_lib.add_source_files(join(uvvm_root, 'uvvm_util', 'src', '*.vhd'))

bitvis_vip_spi_lib = ui.add_library('bitvis_vip_sbi')
bitvis_vip_spi_lib.add_source_files(join(uvvm_root, 'bitvis_vip_sbi', 'src', '*.vhd'))

# Add all testbenches to lib
lib = ui.add_library('lib')
lib.add_source_files(join(root, 'test', 'tb_uvvm_integration.vhd'))

# Compile and run all test cases
ui.main()
