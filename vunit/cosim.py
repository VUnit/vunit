# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Utils for co-execution of a dynamically loadable binaries or shared libraries
"""

import sys
from sys import platform
from os.path import isfile
import ctypes
import _ctypes  # type: ignore


def dlopen(path):
    """
    Open/load a PIE binary or a shared library.
    """
    if not isfile(path):
        print("Executable binary not found: " + path)
        sys.exit(1)
    try:
        return ctypes.CDLL(path)
    except OSError:
        print(
            "Loading executables dynamically seems not to be supported on this platform"
        )
        sys.exit(1)


def dlclose(obj):
    """
    Close/unload a PIE binary or a shared library.

    :param obj: object returned by ctypes.CDLL when the resource was loaded
    """
    if platform == "win32":
        _ctypes.FreeLibrary(obj._handle)  # pylint:disable=protected-access,no-member
    else:
        _ctypes.dlclose(obj._handle)  # pylint:disable=protected-access,no-member


def enc_args(args):
    """
    Convert args to a suitable format for a foreign C function.

    :param args: list of strings
    """
    xargs = (ctypes.POINTER(ctypes.c_char) * len(args))()
    for idx, arg in enumerate(args):
        xargs[idx] = ctypes.create_string_buffer(arg.encode("utf-8"))
    return xargs


def byte_buf(lst):
    """
    Convert array to a string buffer (uint8_t* in C).

    :param lst: list of naturals range [0,255]
    """
    return ctypes.create_string_buffer(bytes(lst), len(lst))


def int_buf(lst, bpw=4, signed=True):
    """
    Convert array to a string buffer (uint8_t* in C).

    :param lst: list of integers
    :param bpw: number of bytes per word/integer
    :param signed: whether to encode the numbers as signed
    """
    out = [None] * 4 * len(lst)
    for idx, val in enumerate(lst):
        out[idx * 4 : idx * 4 + 4] = (val).to_bytes(
            bpw, byteorder="little", signed=signed
        )
    return byte_buf(out)


def read_byte_buf(buf):
    """
    Read byte/string buffer (uint8_t* in C) as a list of numbers.
    """
    return read_int_buf(buf, bpw=1, signed=False)


def read_int_buf(buf, bpw=4, signed=True):
    """
    Read byte/string buffer as a list of numbers.

    :param buf: byte/string buffer (uint8_t* in C) to read from
    :param bpw: number of bytes per word/integer
    :param signed: whether to decode the numbers as signed
    """
    out = [None] * int(len(buf) / bpw)
    if bpw == 1:
        for idx, val in enumerate(buf):
            out[idx] = int.from_bytes(val, byteorder="little", signed=signed)
    else:
        for idx, _ in enumerate(out):
            out[idx] = int.from_bytes(
                buf[idx * bpw : idx * bpw + bpw], byteorder="little", signed=signed
            )
    return out
