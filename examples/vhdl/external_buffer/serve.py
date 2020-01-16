# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

import ctypes
from os.path import join, dirname
from vunit import VUnit
from websim import *


root = dirname(__file__)


# Allocate and define shared data buffers

data = [3 * c for c in range(64)]

buf = [[] for c in range(2)]
buf[1] = byte_buf(data + [0 for x in range(2 * len(data))])

buf[0] = int_buf(
    [-(2 ** 31) + 1, -(2 ** 31), 0, 1, len(data)]  # clk_step, update, block_length
)


# Load args and define simulation callbacks

sim = None
args = [line.rstrip("\n") for line in open(join(root, "args.txt"))]


def load():
    g = ctypes.CDLL(args[0])
    sim.handler(g)

    for idx, val in enumerate(buf):
        g.set_string_ptr(idx, val)

    xargs = enc_args(args)
    return g.ghdl_main(len(xargs) - 1, xargs)


def update_cb():
    p = read_int_buf(buf[0])[0:3]
    p[0] -= -(2 ** 31)
    p[1] -= -(2 ** 31)
    return {
        "name": "external_buffer",
        "params": p,
        "data": {"mem": read_byte_buf(buf[1])},
    }


def unload():
    dlclose(sim.handler())


# Instantiate WebSim and run server

sim = WebSim(
    dist=join(root, "..", "vue", "dist"),
    load_cb=load,
    unload_cb=unload,
    update_cb=update_cb,
)

sim.run()
