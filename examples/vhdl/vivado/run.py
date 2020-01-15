# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Vivado IP
---------

Demonstrates compiling and performing behavioral simulation of
Vivado IPs with VUnit.
"""

from os.path import join, dirname
from vunit import VUnit
from vivado_util import add_vivado_ip

root = dirname(__file__)
src_path = join(root, "src")

vu = VUnit.from_argv()

vu.add_library("lib").add_source_files(join(src_path, "*.vhd"))
vu.add_library("tb_lib").add_source_files(join(src_path, "test", "*.vhd"))

add_vivado_ip(
    vu,
    output_path=join(root, "vivado_libs"),
    project_file=join(root, "myproject", "myproject.xpr"),
)

vu.main()
