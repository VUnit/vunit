# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Runtime of the Python bridge.

This module is executed *inside the simulator process* by the embedded
interpreter of the native bridge (native/*.c). It is loaded by file
path, not imported from the vunit package, and must therefore not import
anything from vunit. It is a private implementation detail of the VHDL
exec/eval operations.
"""

import builtins
import linecache
import math
import numbers
import os
import struct
import sys
import traceback
from pathlib import Path
import __main__

# Result kinds, must match python_ffi_pkg
KIND_INTEGER = 0
KIND_REAL = 1
KIND_BOOLEAN = 2
KIND_STRING = 3
KIND_STD_ULOGIC = 4
KIND_STD_ULOGIC_VECTOR = 5
KIND_SIGNED = 6
KIND_UNSIGNED = 7
KIND_INTEGER_ARRAY = 8
KIND_INTEGER_VECTOR = 9
KIND_REAL_VECTOR = 10

VHDL_TYPE_NAMES = {
    KIND_INTEGER: "integer",
    KIND_REAL: "real",
    KIND_BOOLEAN: "boolean",
    KIND_STRING: "string",
    KIND_STD_ULOGIC: "std_ulogic",
    KIND_STD_ULOGIC_VECTOR: "std_ulogic_vector",
    KIND_SIGNED: "signed",
    KIND_UNSIGNED: "unsigned",
    KIND_INTEGER_ARRAY: "integer_array_t",
    KIND_INTEGER_VECTOR: "integer_vector",
    KIND_REAL_VECTOR: "real_vector",
}

STD_ULOGIC_VALUES = frozenset("UX01ZWLH-")
INTEGER_LOW = -(2**31)
INTEGER_HIGH = 2**31 - 1
TEXT_ENCODING = "utf-8"
TEXT_ERRORS = "surrogateescape"

DEFAULT_SESSION = "default"

# Name of the bridge object injected into every session namespace.
HANDLE_NAME = "__vunit__"

_NO_VALUE = object()


def _type_name(value):
    return type(value).__qualname__


def _is_bool(value):
    """True for Python and NumPy booleans."""
    if isinstance(value, bool):
        return True
    numpy = sys.modules.get("numpy")
    return numpy is not None and isinstance(value, numpy.bool_)


def _is_float(value):
    """
    True for Python and NumPy floats only.

    An int is not accepted, matching the PyFloat_Check of the other
    python_ffi_pkg implementations.
    """
    if isinstance(value, float):
        return True
    numpy = sys.modules.get("numpy")
    return numpy is not None and isinstance(value, numpy.floating)


def _is_integer(value):
    """True for Python and NumPy integers, but not for booleans."""
    return not _is_bool(value) and isinstance(value, numbers.Integral)


def _encode(text):
    return text.encode(TEXT_ENCODING, TEXT_ERRORS)


def _type_error(kind, value, expected):
    """
    The error raised when a Python value cannot become the requested VHDL type.

    The operation it belongs to (exec, eval, call, ...) is added by VHDL.
    """
    return TypeError(
        f"Cannot convert Python {_type_name(value)} ({value!r:.200}) "
        f"to VHDL {VHDL_TYPE_NAMES[kind]}; expected {expected}"
    )


class StagedValues:
    """
    Values transferred from VHDL and kept under an id.

    VHDL transfers an integer_array_t once and then refers to it as
    ``__vunit__.staged(<id>)`` in the Python expressions it evaluates. Staged
    values live until the simulation ends, or until python_cleanup releases
    them early, so that one VHDL constant can be used in several calls. Every
    use gets its own copy of the NumPy array so that a function modifying it in
    place does not affect the next use.
    """

    def __init__(self):
        self._values = {}  # id -> (value, bit_width, is_signed)

    def stage(self, value, bit_width, is_signed):
        """
        Stage a value and return its id.
        """
        staged_id = len(self._values) + 1
        self._values[staged_id] = (value, bit_width, bool(is_signed))
        return staged_id

    def get(self, staged_id):
        """
        A copy of a staged value with its metadata, as (value, bit_width, is_signed).
        """
        entry = self._values.get(staged_id)
        if entry is None:
            raise ValueError(f"There is no value staged under the id {staged_id!r}")
        value, bit_width, is_signed = entry
        numpy = sys.modules.get("numpy")
        if numpy is not None and isinstance(value, numpy.ndarray):
            # The user code may modify it in place, keep the staged value intact
            value = value.copy()
        return (value, bit_width, is_signed)

    def clear(self):
        """
        Drop all staged values.
        """
        self._values.clear()


class BridgeHandle:
    """
    The ``__vunit__`` object that VHDL-generated Python expressions use.

    It is the only name the bridge adds to a session namespace.
    """

    def __init__(self, runtime):
        self._runtime = runtime

    def staged(self, staged_id):
        """
        The value VHDL staged under the given id.
        """
        return self._runtime.staged(staged_id)

    def __repr__(self):
        return "<VUnit python bridge>"


class Runtime:  # pylint: disable=too-many-instance-attributes
    """
    State of the embedded Python session: one persistent namespace per session,
    shared by all exec and eval operations of a simulation.
    """

    def __init__(self, run_script_dir, prefix):
        self._run_script_dir = Path(run_script_dir)
        self._handle = BridgeHandle(self)
        # One namespace per session. The default session uses __main__.
        self._sessions = {DEFAULT_SESSION: __main__.__dict__}
        __main__.__dict__[HANDLE_NAME] = self._handle
        self._session = DEFAULT_SESSION
        self._exec_count = 0
        self._eval_count = 0
        self._result = _NO_VALUE
        # Metadata of the integer_array_t values handed to the current
        # operation, keyed by id() of the NumPy array created for them.
        self._array_meta = {}
        self._staged = StagedValues()

        self._check_environment(prefix)

        # Mimic "python run.py": the run script directory is sys.path[0]. It is
        # not used to resolve file names, which VHDL does, but import_run_script
        # imports the run script as a module and it can then import its siblings
        # like it does when the run script is started by python.
        if str(self._run_script_dir) not in sys.path:
            sys.path.insert(0, str(self._run_script_dir))

    @staticmethod
    def _check_environment(prefix):
        """
        The embedded interpreter must use the Python environment that launched VUnit.
        """

        def normalize(path):
            return os.path.normcase(os.path.realpath(path))

        if normalize(sys.prefix) != normalize(prefix):
            raise RuntimeError(
                f"The embedded Python interpreter selected the environment {sys.prefix!r} "
                f"but VUnit was started from {prefix!r}"
            )

    @staticmethod
    def _flush():
        """
        Flush Python's output so that it is ordered with the simulator's output.
        """
        for stream in (sys.stdout, sys.stderr):
            try:
                if stream is not None:
                    stream.flush()
            except Exception:  # pylint: disable=broad-except
                pass

    def format_exception(self, exc):
        """
        Format an exception with its traceback, hiding frames of this module.
        """
        this_file = os.path.normcase(os.path.abspath(__file__))
        traceback_ = exc.__traceback__
        while traceback_ is not None and (
            os.path.normcase(os.path.abspath(traceback_.tb_frame.f_code.co_filename)) == this_file
        ):
            traceback_ = traceback_.tb_next
        self._flush()
        return "".join(traceback.format_exception(type(exc), exc, traceback_)).rstrip("\n")

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def setup(self):
        """
        Prepare for the operations to come. Idempotent: the interpreter and the
        namespaces are created once and python_setup may be called any number
        of times. Calling it at all is optional since every operation starts
        the interpreter if it is not running.
        """
        self._flush()

    def cleanup(self):
        """
        Release what the simulation acquired: the last result and the staged
        values. The interpreter and the session namespaces are kept, so
        operations after python_cleanup keep working. Calling it at all is
        optional: it only releases these values earlier than the end of the
        simulator process, and every operation flushes on its own.
        """
        self._result = _NO_VALUE
        self._staged.clear()
        self._array_meta.clear()
        self._flush()

    def select_session(self, name):
        """
        Make the namespace of a session current, creating it on first use.
        """
        if name not in self._sessions:
            self._sessions[name] = {
                "__name__": "__main__",
                "__builtins__": builtins,
                HANDLE_NAME: self._handle,
            }
        self._session = name
        self._result = _NO_VALUE
        self._array_meta = {}

    @property
    def _namespace(self):
        """
        Namespace of the current session.
        """
        return self._sessions[self._session]

    def _source_name(self, operation, count):
        """
        Pseudo file name of inline source code, shown in tracebacks.
        """
        if self._session == DEFAULT_SESSION:
            return f"<{operation} #{count}>"
        return f"<{operation} {self._session} #{count}>"

    # ------------------------------------------------------------------
    # exec
    # ------------------------------------------------------------------

    def execute(self, text, is_file):
        """
        Execute inline source code or a Python file in the persistent namespace.
        """
        try:
            if is_file:
                self._execute_file(text)
            else:
                self._execute_source(text)
        finally:
            self._flush()

    def _execute_source(self, source):
        """
        Execute inline source code, registered in linecache for readable tracebacks.
        """
        self._exec_count += 1
        file_name = self._source_name("exec", self._exec_count)
        # Make tracebacks show the source lines of inline code
        linecache.cache[file_name] = (len(source), None, source.splitlines(True), file_name)
        code = compile(source, file_name, "exec", dont_inherit=True)
        exec(code, self._namespace, self._namespace)  # pylint: disable=exec-used

    @staticmethod
    def _resolve_file(file_name):
        """
        Absolute path of a Python file. VHDL resolves a relative file name
        against the directory of its testbench before it gets here.
        """
        if file_name == "":
            raise ValueError("Empty Python file name")
        return Path(os.path.normpath(Path(file_name).absolute()))

    def _execute_file(self, file_name):
        """
        Execute a Python file with __file__ set and its directory on sys.path.
        """
        path = self._resolve_file(file_name)
        with open(path, encoding="utf-8") as fptr:
            source = fptr.read()
        code = compile(source, str(path), "exec", dont_inherit=True)

        namespace = self._namespace
        previous_file = namespace.get("__file__", _NO_VALUE)
        directory = str(path.parent)
        namespace["__file__"] = str(path)
        # Let the file import its sibling modules
        sys.path.insert(0, directory)
        try:
            exec(code, namespace, namespace)  # pylint: disable=exec-used
        finally:
            try:
                sys.path.remove(directory)
            except ValueError:
                pass
            if previous_file is _NO_VALUE:
                namespace.pop("__file__", None)
            else:
                namespace["__file__"] = previous_file

    # ------------------------------------------------------------------
    # eval
    # ------------------------------------------------------------------

    def evaluate(self, text, kind, width):
        """
        Evaluate a Python expression in the session namespace and convert the
        value to the VHDL type given by kind.

        :param width: Width of a std_ulogic_vector/signed/unsigned result, -1 if not given by VHDL.
        :returns: (integer, real, data bytes, metadata tuple)
        """
        self._result = _NO_VALUE
        self._array_meta = {}
        self._eval_count += 1
        file_name = self._source_name("eval", self._eval_count)
        try:
            # Make tracebacks show the source lines of the expression
            linecache.cache[file_name] = (len(text), None, text.splitlines(True), file_name)
            code = compile(text, file_name, "eval", dont_inherit=True)
            # Running the user's own Python code is the purpose of this module
            self._result = eval(code, self._namespace, self._namespace)  # pylint: disable=eval-used
        except BaseException:
            self._array_meta = {}
            self._flush()
            raise
        self._flush()
        return self.convert_result(kind, width)

    # ------------------------------------------------------------------
    # Values transferred from VHDL
    # ------------------------------------------------------------------

    def staged(self, staged_id):
        """
        The value staged under an id, used from Python as __vunit__.staged(id).
        """
        value, bit_width, is_signed = self._staged.get(staged_id)
        numpy = sys.modules.get("numpy")
        if numpy is not None and isinstance(value, numpy.ndarray):
            # An expression returning this very array keeps its word size
            self._array_meta[id(value)] = (value, bit_width, is_signed)
        return value

    def stage_value(self, value):
        """
        Stage a value transferred from VHDL and return its id.
        """
        meta = self._array_meta.get(id(value))
        if meta is not None and meta[0] is value:
            bit_width, is_signed = meta[1], meta[2]
        else:
            bit_width, is_signed = 32, True
        return self._staged.stage(value, bit_width, is_signed)

    @staticmethod
    def _numpy():
        """
        Import NumPy, which is only needed when integer_array_t values are exchanged.
        """
        try:
            import numpy  # type: ignore[import-not-found]  # pylint: disable=import-outside-toplevel
        except ImportError as exc:
            raise ImportError(
                "integer_array_t values are exchanged as NumPy arrays but NumPy could not be imported "
                f"in the Python environment used by VUnit ({sys.executable}): {exc}"
            ) from exc
        return numpy

    @staticmethod
    def _shape(length, width, height, depth):
        """
        NumPy shape of an integer_array_t. get(arr, x, y) is a[y, x] and
        get(arr, x, y, z) is a[y, x, z], matching VUnit's storage order.
        """
        if depth > 1:
            return (height, width, depth)
        if height > 1:
            return (height, width)
        return (length,)

    def make_array(
        self, storage, length, width, height, depth, bit_width, is_signed
    ):  # pylint: disable=too-many-arguments,too-many-positional-arguments
        """
        Create the NumPy array for an integer_array_t value. The bridge
        fills the storage (native int32) after this call returns.
        """
        numpy = self._numpy()
        array = numpy.frombuffer(storage, dtype=numpy.int32).reshape(self._shape(length, width, height, depth))
        self._array_meta[id(array)] = (array, bit_width, bool(is_signed))
        return array

    # ------------------------------------------------------------------
    # Results
    # ------------------------------------------------------------------

    def convert_result(self, kind, width):
        """
        Convert the value of the last evaluation to the VHDL type given by kind.

        :param width: Width of a std_ulogic_vector/signed/unsigned result, -1 if not given by VHDL.
        :returns: (integer, real, data bytes, metadata tuple)
        """
        value = self._result
        self._result = _NO_VALUE
        array_meta = self._array_meta
        self._array_meta = {}
        if value is _NO_VALUE:
            raise RuntimeError("Internal error: no Python result available")

        converters = {
            KIND_INTEGER: self._integer_result,
            KIND_REAL: self._real_result,
            KIND_BOOLEAN: self._boolean_result,
            KIND_STRING: self._string_result,
            KIND_STD_ULOGIC: self._std_ulogic_result,
            KIND_STD_ULOGIC_VECTOR: self._std_ulogic_vector_result,
            KIND_SIGNED: self._bits_result,
            KIND_UNSIGNED: self._bits_result,
            KIND_INTEGER_VECTOR: self._integer_vector_result,
            KIND_REAL_VECTOR: self._real_vector_result,
        }
        if kind == KIND_INTEGER_ARRAY:
            return self._array_result(value, array_meta)
        if kind not in converters:
            raise RuntimeError(f"Internal error: unknown result kind {kind}")
        return converters[kind](kind, value, width)

    @staticmethod
    def _integer_result(kind, value, _width):
        """
        Convert an int result.
        """
        if not _is_integer(value):
            raise _type_error(kind, value, "int")
        value = int(value)
        if not INTEGER_LOW <= value <= INTEGER_HIGH:
            raise OverflowError(f"{value} is outside the range of VHDL integer ({INTEGER_LOW} to {INTEGER_HIGH})")
        return (value, 0.0, b"", ())

    @staticmethod
    def _real_result(kind, value, _width):
        """
        Convert a float result. An int is not a float, like in Python's C API.
        """
        if not _is_float(value):
            raise _type_error(kind, value, "float")
        result = float(value)
        if not math.isfinite(result):
            raise ValueError(f"{result} cannot be represented as VHDL real")
        return (0, result, b"", ())

    @staticmethod
    def _boolean_result(kind, value, _width):
        """
        Convert a bool result.
        """
        if not _is_bool(value):
            raise _type_error(kind, value, "bool")
        return (int(bool(value)), 0.0, b"", ())

    @staticmethod
    def _string_result(kind, value, _width):
        """
        Convert a str result to UTF-8.
        """
        if not isinstance(value, str):
            raise _type_error(kind, value, "str")
        data = _encode(value)
        return (0, 0.0, data, (len(data),))

    @staticmethod
    def _std_ulogic_result(kind, value, _width):
        """
        Convert a one character str result.
        """
        if not isinstance(value, str) or len(value) != 1 or value not in STD_ULOGIC_VALUES:
            raise _type_error(kind, value, "a one character str, one of 'UX01ZWLH-'")
        return (0, 0.0, value.encode("ascii"), (1,))

    @staticmethod
    def _std_ulogic_vector_result(kind, value, width):
        """
        Convert a str result, one character per element.
        """
        if not isinstance(value, str) or not STD_ULOGIC_VALUES.issuperset(value):
            raise _type_error(kind, value, "a str of the characters 'UX01ZWLH-'")
        if width >= 0 and len(value) != width:
            raise ValueError(f"Got {len(value)} std_ulogic values but the VHDL result has length {width}")
        return (0, 0.0, value.encode("ascii"), (len(value),))

    def _bits_result(self, kind, value, width):
        """
        Convert an int result to the bits of a signed/unsigned.
        """
        data = self._int_to_bits(kind, value, width)
        return (0, 0.0, data, (len(data),))

    @staticmethod
    def _int_to_bits(kind, value, width):
        """
        Two's complement/binary image of an int, checked to fit width.
        """
        if not _is_integer(value):
            raise _type_error(kind, value, "int")
        value = int(value)
        is_signed = kind == KIND_SIGNED
        if is_signed:
            low, high = (-(1 << (width - 1)), (1 << (width - 1)) - 1) if width > 0 else (0, -1)
        else:
            low, high = 0, (1 << width) - 1
        if not low <= value <= high:
            raise OverflowError(f"{value} does not fit in a {width} bit {VHDL_TYPE_NAMES[kind]} ({low} to {high})")
        if width == 0:
            return b""
        return format(value & ((1 << width) - 1), f"0{width}b").encode("ascii")

    @staticmethod
    def _sequence(kind, value):
        """
        The elements of a list/tuple result. Nothing else is accepted, like in
        the other python_ffi_pkg implementations.
        """
        if not isinstance(value, (list, tuple)):
            raise _type_error(kind, value, "a list or tuple")
        return value

    def _integer_vector_result(self, kind, value, _width):
        """
        Convert a list/tuple of int to integer_vector data (native int32).
        """
        values = self._sequence(kind, value)
        integers = []
        for index, element in enumerate(values):
            if not _is_integer(element):
                raise TypeError(
                    f"Cannot convert element {index} of the Python {_type_name(value)}, "
                    f"a {_type_name(element)} ({element!r:.100}), to a VHDL integer; expected int"
                )
            element = int(element)
            if not INTEGER_LOW <= element <= INTEGER_HIGH:
                raise OverflowError(
                    f"Element {index} ({element}) is outside the range of VHDL integer "
                    f"({INTEGER_LOW} to {INTEGER_HIGH})"
                )
            integers.append(element)
        data = struct.pack(f"={len(integers)}i", *integers)
        return (0, 0.0, data, (len(integers),))

    def _real_vector_result(self, kind, value, _width):
        """
        Convert a list/tuple of float to real_vector data (native float64).
        """
        values = self._sequence(kind, value)
        reals = []
        for index, element in enumerate(values):
            if not _is_float(element):
                raise TypeError(
                    f"Cannot convert element {index} of the Python {_type_name(value)}, "
                    f"a {_type_name(element)} ({element!r:.100}), to a VHDL real; expected float"
                )
            element = float(element)
            if not math.isfinite(element):
                raise ValueError(f"Element {index} ({element}) cannot be represented as VHDL real")
            reals.append(element)
        data = struct.pack(f"={len(reals)}d", *reals)
        return (0, 0.0, data, (len(reals),))

    _DTYPE_WORD_SIZE = {
        # dtype.str without byte order: (bit_width, is_signed)
        "b1": (1, False),
        "i1": (8, True),
        "u1": (8, False),
        "i2": (16, True),
        "u2": (16, False),
        "i4": (32, True),
    }

    def _array_result(self, value, array_meta):
        """
        Convert a NumPy array (or nested int sequence) to integer_array_t data.
        """
        numpy = self._numpy()
        original = value
        value = self._integer_ndarray(numpy, value)
        bit_width, is_signed = self._word_size(original, value, array_meta)

        low, high = (-(1 << (bit_width - 1)), (1 << (bit_width - 1)) - 1) if is_signed else (0, (1 << bit_width) - 1)
        if value.size > 0:
            minimum, maximum = int(value.min()), int(value.max())
            if minimum < low or maximum > high:
                raise OverflowError(
                    f"The array values ({minimum} to {maximum}) do not fit in "
                    f"the integer_array_t word size ({bit_width} bit {'signed' if is_signed else 'unsigned'}, "
                    f"{low} to {high})"
                )

        # get(arr, x, y, z) is value[y, x, z]
        height, width, depth = (value.shape + (1, 1))[:3] if value.ndim > 1 else (1, value.shape[0], 1)

        data = numpy.ascontiguousarray(value, dtype=numpy.int32).tobytes()
        return (0, 0.0, data, (value.size, width, height, depth, bit_width, int(is_signed)))

    @staticmethod
    def _integer_ndarray(numpy, value):
        """
        The result as an integer NumPy array with 1 to 3 dimensions.
        """
        if not isinstance(value, numpy.ndarray):
            if isinstance(value, (str, bytes)) or not isinstance(value, (list, tuple)):
                raise _type_error(KIND_INTEGER_ARRAY, value, "a NumPy array of integers")
            value = numpy.asarray(value)

        if value.dtype.kind not in "biu":
            raise TypeError(
                f"Cannot convert a NumPy array of dtype {value.dtype} to a VHDL integer_array_t; "
                "expected an integer or boolean dtype"
            )
        if value.ndim not in (1, 2, 3):
            raise ValueError(
                f"Cannot convert a {value.ndim}-dimensional NumPy array to a VHDL integer_array_t; "
                "expected 1, 2 or 3 dimensions"
            )
        return value

    def _word_size(self, original, value, array_meta):
        """
        bit_width and is_signed of a returned array.
        """
        meta = array_meta.get(id(original))
        if meta is not None and meta[0] is original and meta[1] >= 1:
            # The expression returned (possibly modified in place) one of the
            # integer_array_t values VHDL staged: keep its bit width and signedness.
            return meta[1], meta[2]
        return self._DTYPE_WORD_SIZE.get(value.dtype.str[1:], (32, True))
