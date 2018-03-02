# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit
from itertools import product

root = dirname(__file__)

ui = VUnit.from_argv()
ui.add_random()
ui.add_verification_components()
lib = ui.library("vunit_lib")
lib.add_source_files(join(root, "test", "*.vhd"))


def gen_wb_slave_tests(obj, dat_width, num_cycles, max_ack_dly):
    for dat_width, num_cycles, max_ack_dly \
		in product(dat_width, num_cycles, max_ack_dly):
        config_name = "dat_width=%i,num_cycles=%i,max_ack_dly=%i" % \
        	(dat_width, num_cycles, max_ack_dly)
        obj.add_config(name=config_name,
                       generics=dict(
                           dat_width=dat_width,
                           adr_width=8,
                           max_ack_dly=max_ack_dly,
                           rand_stall=False,
                           num_cycles=num_cycles))


tb_wishbone_slave = lib.test_bench("tb_wishbone_slave")

for test in tb_wishbone_slave.get_tests():
    gen_wb_slave_tests(test, [8, 32], [1, 10], [0, 1, 2])

ui.main()


