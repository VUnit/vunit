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


def encode(tb_cfg):
    return ",".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])


def gen_wb_tests(obj, *args):
    for dat_width, num_cycles, strobe_prob, ack_prob, stall_prob in product(*args):
        tb_cfg = dict(
            dat_width=dat_width,
            #  TODO remove fixed addr
            adr_width=32,
            strobe_prob=strobe_prob,
            ack_prob=ack_prob,
            stall_prob=stall_prob,
            num_cycles=num_cycles)
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name,
                       generics=dict(encoded_tb_cfg=encode(tb_cfg)))


def gen_avalon_tests(obj, *args):
    for data_width, num_cycles, readdatavalid_prob, waitrequest_prob, in product(*args):
        tb_cfg = dict(
            data_width=data_width,
            readdatavalid_prob=readdatavalid_prob,
            waitrequest_prob=waitrequest_prob,
            num_cycles=num_cycles)
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name,
                       generics=dict(encoded_tb_cfg=encode(tb_cfg)))


def gen_avalon_master_tests(obj, *args):
    for transfers, readdatavalid_prob, waitrequest_prob, write_prob, read_prob, in product(*args):
        tb_cfg = dict(
            readdatavalid_prob=readdatavalid_prob,
            waitrequest_prob=waitrequest_prob,
            write_prob=write_prob,
            read_prob=read_prob,
            transfers=transfers)
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name,
                       generics=dict(encoded_tb_cfg=encode(tb_cfg)))


tb_avalon_slave = lib.test_bench("tb_avalon_slave")

for test in tb_avalon_slave.get_tests():
    gen_avalon_tests(test, [32], [1, 2, 64], [1.0, 0.3], [0.0, 0.4])

tb_avalon_master = lib.test_bench("tb_avalon_master")

for test in tb_avalon_master.get_tests():
    if test.name == "wr single rd single":
        gen_avalon_master_tests(test, [1], [1.0], [0.0], [1.0], [1.0])
    else:
        gen_avalon_master_tests(test, [16], [1.0, 0.3], [0.0, 0.7], [1.0, 0.3], [1.0, 0.3])

tb_wishbone_slave = lib.test_bench("tb_wishbone_slave")

for test in tb_wishbone_slave.get_tests():
    #  TODO strobe_prob not implemented in slave tb
    gen_wb_tests(test, [8, 32], [1, 64], [1.0], [0.3, 1.0], [0.4, 0.0])


tb_wishbone_master = lib.test_bench("tb_wishbone_master")

for test in tb_wishbone_master.get_tests():
    gen_wb_tests(test, [8, 32], [1, 64], [0.3, 1.0], [0.3, 1.0], [0.4, 0.0])

tb_axi_stream_protocol_checker = lib.test_bench("tb_axi_stream_protocol_checker")

for data_length in [0, 8]:
    for test in tb_axi_stream_protocol_checker.get_tests("*passing*tdata*"):
        test.add_config(name="data_length=%d" % data_length, generics=dict(data_length=data_length))

for test in tb_axi_stream_protocol_checker.get_tests("*failing*tid width*"):
    test.add_config(name="dest_length=25", generics=dict(dest_length=25))
    test.add_config(name="id_length=8 dest_length=17", generics=dict(id_length=8, dest_length=17))

test_failing_max_waits = tb_axi_stream_protocol_checker.test(
    "Test failing check of that tready comes within max_waits after valid")
for max_waits in [0, 8]:
    test_failing_max_waits.add_config(name="max_waits=%d" % max_waits, generics=dict(max_waits=max_waits))


ui.main()
