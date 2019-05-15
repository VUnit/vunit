# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com


from vunit.cosim import *
import ctypes
from os.path import join, dirname, isfile
from sys import argv
from json import load


if len(argv) != 2:
    print("A single argument is required and supported!")
    exit(1)

with open(join(dirname(__file__), "vunit_out", "cosim", '%s.json' % argv[1])) as json_file:
    args = load(json_file)
    if "integer" not in argv[1]:
        new_buf = byte_buf
        read_buf = read_byte_buf
    else:
        new_buf = int_buf
        read_buf = read_int_buf

xargs = enc_args(args)

print("\nREGULAR EXECUTION")
ghdl = dlopen(args[0])
try:
    ghdl.main(len(xargs)-1, xargs)
# FIXME With VHDL 93, the execution is Aborted and Python exits here
except SystemExit as exc:
    if exc.code != 0:
        exit(exc.code)
dlclose(ghdl)

print("\nPYTHON ALLOCATION")
ghdl = dlopen(args[0])

data = [111, 122, 133, 144, 155]

# Allocate and initialize shared data buffer
buf = new_buf(data + [0 for x in range(2*len(data))])

ghdl.set_string_ptr(0, buf)

for i, v in enumerate(read_buf(buf)):
    print("py " + str(i) + ": " + str(v))

ghdl.ghdl_main(len(xargs)-1, xargs)

for i, v in enumerate(read_buf(buf)):
    print("py " + str(i) + ": " + str(v))

dlclose(ghdl)
