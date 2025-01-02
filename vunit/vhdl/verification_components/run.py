# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from itertools import product
from vunit import VUnit

ROOT = Path(__file__).parent

UI = VUnit.from_argv()
UI.add_vhdl_builtins()
UI.add_random()
UI.add_verification_components()

LIB = UI.library("vunit_lib")
LIB.add_source_files(ROOT / "test" / "*.vhd")


def encode(tb_cfg):
    return ",".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])


def gen_wb_tests(obj, *args):
    for dat_width, num_cycles, strobe_prob, ack_prob, stall_prob, slave_inst in product(*args):
        tb_cfg = dict(
            dat_width=dat_width,
            #  TODO remove fixed addr
            adr_width=32,
            strobe_prob=strobe_prob,
            ack_prob=ack_prob,
            stall_prob=stall_prob,
            num_cycles=num_cycles,
            slave_inst=slave_inst,
        )
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name, generics=dict(encoded_tb_cfg=encode(tb_cfg)))


def gen_avalon_tests(obj, *args):
    for data_width, num_cycles, readdatavalid_prob, waitrequest_prob in product(*args):
        tb_cfg = dict(
            data_width=data_width,
            readdatavalid_prob=readdatavalid_prob,
            waitrequest_prob=waitrequest_prob,
            num_cycles=num_cycles,
        )
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name, generics=dict(encoded_tb_cfg=encode(tb_cfg)))


def gen_avalon_master_tests(obj, *args):
    for (
        transfers,
        readdatavalid_prob,
        waitrequest_prob,
        write_prob,
        read_prob,
    ) in product(*args):
        tb_cfg = dict(
            readdatavalid_prob=readdatavalid_prob,
            waitrequest_prob=waitrequest_prob,
            write_prob=write_prob,
            read_prob=read_prob,
            transfers=transfers,
        )
        config_name = encode(tb_cfg)
        obj.add_config(name=config_name, generics=dict(encoded_tb_cfg=encode(tb_cfg)))


tb_avalon_slave = LIB.test_bench("tb_avalon_slave")

for test in tb_avalon_slave.get_tests():
    gen_avalon_tests(test, [32], [1, 2, 64], [1.0, 0.3], [0.0, 0.4])

tb_avalon_master = LIB.test_bench("tb_avalon_master")

for test in tb_avalon_master.get_tests():
    if test.name == "wr single rd single":
        gen_avalon_master_tests(test, [1], [1.0], [0.0], [1.0], [1.0])
    else:
        gen_avalon_master_tests(test, [64], [1.0, 0.3], [0.0, 0.7], [1.0, 0.3], [1.0, 0.3])

TB_WISHBONE_SLAVE = LIB.test_bench("tb_wishbone_slave")

for test in TB_WISHBONE_SLAVE.get_tests():
    #  TODO strobe_prob not implemented in slave tb
    gen_wb_tests(
        test,
        [8, 32],
        [1, 64],
        [1.0],
        [0.3, 1.0],
        [0.4, 0.0],
        [
            True,
        ],
    )


TB_WISHBONE_MASTER = LIB.test_bench("tb_wishbone_master")

for test in TB_WISHBONE_MASTER.get_tests():
    if test.name == "slave comb ack":
        gen_wb_tests(
            test,
            [32],
            [64],
            [1.0],
            [1.0],
            [0.0],
            [
                False,
            ],
        )
    else:
        gen_wb_tests(
            test,
            [8, 32],
            [1, 64],
            [0.3, 1.0],
            [0.3, 1.0],
            [0.4, 0.0],
            [
                True,
            ],
        )


TB_AXI_STREAM = LIB.test_bench("tb_axi_stream")

for id_length in [0, 8]:
    for dest_length in [0, 8]:
        for user_length in [0, 8]:
            for data_length in [8, 16]:
                for test in TB_AXI_STREAM.get_tests("*check"):
                    test.add_config(
                        name=f"id_l={id_length} dest_l={dest_length} user_l={user_length} data_l={data_length}",
                        generics=dict(
                            g_data_length=data_length,
                            g_id_length=id_length,
                            g_dest_length=dest_length,
                            g_user_length=user_length,
                        ),
                    )

TB_AXI_STREAM.test("test passing with no tkeep").set_generic("g_data_length", 16)

TB_AXI_STREAM_PROTOCOL_CHECKER = LIB.test_bench("tb_axi_stream_protocol_checker")

for data_length in [0, 8, 32]:
    for test in TB_AXI_STREAM_PROTOCOL_CHECKER.get_tests("*passing*tdata*"):
        test.add_config(name="data_length=%d" % data_length, generics=dict(data_length=data_length))

for test in TB_AXI_STREAM_PROTOCOL_CHECKER.get_tests("*failing*tid width*"):
    test.add_config(name="dest_length=25", generics=dict(dest_length=25))
    test.add_config(name="id_length=8 dest_length=17", generics=dict(id_length=8, dest_length=17))

TEST_FAILING_MAX_WAITS = TB_AXI_STREAM_PROTOCOL_CHECKER.test(
    "Test failing check of that tready comes within max_waits after valid"
)
for max_waits in [0, 8]:
    TEST_FAILING_MAX_WAITS.add_config(name="max_waits=%d" % max_waits, generics=dict(max_waits=max_waits))

TB_AXI_STREAM.test("test random stall on master").add_config(
    name="stall_master", generics=dict(g_stall_percentage_master=30)
)

TB_AXI_STREAM.test("test random pop stall on slave").add_config(
    name="stall_slave", generics=dict(g_stall_percentage_slave=30)
)

TB_AXI_STREAM.test("test random check stall on slave").add_config(
    name="stall_slave", generics=dict(g_stall_percentage_slave=40)
)

UI.main()
