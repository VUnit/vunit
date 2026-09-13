# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
The model of an imaginary device, imported from VHDL with
import_module_from_file. Keeping a model in a module rather than in exec
strings gives syntax highlighting, linting and a debugger.
"""

import linecache
import math
import traceback

# The status register of the imaginary device this module models
STATUS = 0xBEEF


def check_status(samples, **status):
    """
    A register dump checker taking the samples positionally and every status
    register as a keyword argument. It verifies a few of the registers and
    returns the number of registers it was given.
    """
    if len(samples) != 5:
        raise ValueError(f"Expected 5 samples, got {len(samples)}")
    if status["temperature"] != 42:
        raise ValueError(f"Expected temperature 42, got {status['temperature']}")
    if status["fifo_level"] > status["fifo_depth"]:
        raise ValueError("The FIFO level cannot exceed the FIFO depth")
    return len(status)


def status_text(cycles, offset, value=0, flag=False):
    """
    Show the values exactly as Python received them, so that VHDL can check
    that nothing was lost or wrapped on the way.
    """
    return f"cycles={cycles} offset={offset} value={value} flag={flag}"


def roundtrip(value):
    """
    Return the value unchanged, to send a wide integer back to VHDL.
    """
    return value


def status_word():
    """
    The status register, for call_unsigned.
    """
    return STATUS


def status_bits():
    """
    The status register as std_logic characters, for call_std_logic_vector.
    """
    return format(STATUS, "016b")


def is_busy():
    """
    True while the device has work left, for eval_boolean and call_boolean.
    """
    return bool(STATUS & 1)


def parity():
    """
    Odd parity of the status register as a std_logic character, for call_std_logic.
    """
    return "1" if bin(STATUS).count("1") % 2 else "0"


def status_name():
    """
    The name of the state the device is in, for call_string.
    """
    return "running"


def coefficients():
    """
    The filter coefficients of the device, for call_real_vector.
    """
    return [0.5, -0.25, 0.125]


def sine_table(length):
    """
    A quarter wave sine table with the given number of 16 bit entries, for
    call_integer_vector_ptr. An empty table is a configuration error.
    """
    if length < 1:
        raise ValueError(f"A sine table needs at least one entry, got {length}")
    return [round(32767 * math.sin(math.pi / 2 * index / length)) for index in range(length)]


def failure_text(expression, context):
    """
    The traceback that python_pkg puts in its failure message when expression
    raises, obtained by evaluating the expression here in the same way. It is
    only needed because the test checks the logged message exactly.
    """
    linecache.cache[context] = (len(expression), None, expression.splitlines(True), context)
    try:
        eval(compile(expression, context, "eval"))  # pylint: disable=eval-used
    except BaseException as exc:  # pylint: disable=broad-except
        return "".join(traceback.format_exception(type(exc), exc, exc.__traceback__.tb_next)).rstrip("\n")
    return ""
