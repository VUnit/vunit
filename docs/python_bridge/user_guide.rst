.. _python_bridge:

Calling Python from VHDL
========================

VUnit can embed a Python interpreter in the simulator so that VHDL testbenches
can execute Python code and call Python functions, for example reference
models written with NumPy. The VHDL API, ``python_pkg``/``python_context``, is
enabled with :meth:`add_python() <vunit.ui.VUnit.add_python>`, after
:meth:`add_vhdl_builtins() <vunit.ui.VUnit.add_vhdl_builtins>`:

.. code-block:: python

    from vunit import VUnit

    vu = VUnit.from_argv()
    vu.add_vhdl_builtins()
    vu.add_python()

    lib = vu.add_library("lib")
    lib.add_source_files("*.vhd")

    vu.main()

``python_pkg`` and its foreign language interface, ``python_ffi_pkg``, then
become available through ``python_context``:

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.python_context;

    ...

    exec("import numpy as np");
    result := eval("int(np.sum([1, 2, 3]))");

Requirements
------------

* NVC, GHDL or Questa/ModelSim, through the VUnit Python bridge described
  below, or Riviera-PRO/Active-HDL (VHPI) through the VHPI application, which
  :meth:`add_python() <vunit.ui.VUnit.add_python>` builds in the same way, see
  :ref:`python_bridge:other_simulators`. Any other simulator, or calling
  :meth:`add_python() <vunit.ui.VUnit.add_python>` before
  :meth:`add_vhdl_builtins() <vunit.ui.VUnit.add_vhdl_builtins>`, raises a
  ``RuntimeError``.
* VHDL-2008 or later.
* CPython 3.10 or later with the standard (GIL) build. Free-threaded builds
  are rejected with an error.
* Linux: a C compiler (``cc``, ``gcc`` or ``clang``, or ``CC``) and
  the Python development headers (for example the ``python3-dev`` package)
  since the bridge library is compiled on first use, see
  :ref:`python_bridge:native`. Python must provide a shared ``libpython``
  (``--enable-shared``), which is the case for distribution Pythons,
  ``actions/setup-python``, ``uv`` and ``pyenv`` builds with default settings.
* Windows: a 64-bit CPython from python.org (or compatible, such as
  ``actions/setup-python`` and ``uv``). No compiler is needed for NVC and GHDL;
  Questa uses the MinGW compiler it ships with. MSYS2/MinGW Pythons are not
  supported.

The simulator runs Python in the same environment as VUnit itself, including
an active virtual environment and its installed packages.

A missing prerequisite, for example a missing C compiler or missing Python
headers, is reported by :meth:`add_python() <vunit.ui.VUnit.add_python>` as an
``ERROR`` explaining what to install, after which VUnit exits with code 1.

.. _python_bridge:setup_and_cleanup:

python_setup and python_cleanup
--------------------------------

Both are optional. ``python_setup`` starts the interpreter eagerly, otherwise
it starts on first use. ``python_cleanup`` releases the values staged for
``integer_array_t`` arguments early; they are released anyway when the
simulator process ends. It does *not* finalize the interpreter, so it is safe
to call even if more Python code runs afterwards (for example in another test
case of the same simulation). Output is flushed by every operation and does not
depend on ``python_cleanup``.

.. code-block:: vhdl

    test_runner_setup(runner, runner_cfg);
    python_setup;  -- Optional, the interpreter starts on first use

    ...

    python_cleanup;  -- Optional, releases the staged values early
    test_runner_cleanup(runner);

.. _python_bridge:sessions:

Sessions
--------

Every operation that runs Python code or evaluates a Python expression --
``exec``, ``eval``/``eval_<type>``, ``call``, ``exec_file``,
``import_run_script`` and ``import_module_from_file`` -- takes an optional
trailing parameter,
``session : python_session_t := default_session``, that selects the namespace
the operation runs in. A session is created the first time it is used; the
``default_session`` constant used when the parameter is omitted runs in
``__main__``.

.. code-block:: vhdl

    constant golden : python_session_t := "golden";
    constant fixed_point : python_session_t := "fixed_point";

    ...

    exec("x = 1", session => golden);
    exec_file("models/fixed_point.py", session => fixed_point);

    expected := eval("model(x)", session => golden);
    got := call("model", arg(x), session => fixed_point);

Since ``session`` comes after up to 10 positional arguments in ``call``, it is
normally given by name, as above. Both sessions in the example can define
``model`` without interfering with each other.

On Riviera-PRO/Active-HDL (VHPI), only the default session is supported:
passing any other session fails with a clear error.

Caveats
~~~~~~~

Sessions are separate namespaces in *one* Python interpreter, not separate
interpreters (which would not work with NumPy and many other extension
modules). Consequently, only the names defined by the executed code, such as
functions, classes and variables, are separate. Everything else is shared:

* Imported modules are loaded once and shared by all sessions. A module
  imported in one session is the same module object in another session, so
  changes to module state, such as ``np.random.seed(...)`` or attributes set
  on a module, are visible in all sessions. The same applies to sibling
  modules imported by a Python file executed in several sessions.
* ``sys.path``, ``sys.modules``, environment variables, the current directory
  and open files are process wide.
* Only the default session runs in ``__main__``. Classes defined in other
  sessions report ``__main__`` as their module but cannot be found there,
  which matters for example when pickling their instances.
* All sessions end with the simulation. Test cases run in the same simulation
  (``run_all_in_same_sim``) share the sessions.

exec
----

``exec`` executes a string of Python source code in a persistent namespace
(``__main__`` by default, or another :ref:`session <python_bridge:sessions>`)
that lives until the simulation ends. Names defined by one ``exec`` are
therefore visible to later calls to ``exec`` and ``eval`` on the same session.

.. code-block:: vhdl

    exec("a = -17");
    check_equal(eval("abs(a)"), 17);

Multiline code can be written with an explicit ``LF``, or with the ``+``
operator that ``python_pkg`` defines for strings as a shorthand for ``& LF &``:

.. code-block:: vhdl

    exec(
      "def scale(x, gain):" & LF &
      "    return x * gain"
    );

    exec(
      "import numpy as np" +
      "" +
      "def fibonacci(n):" +
      "    a, b = 0, 1" +
      "    for _ in range(n):" +
      "        a, b = b, a + b" +
      "    return a"
    );

Indentation and blank lines (``""``) are preserved exactly. ``+`` only applies
where a ``string`` is expected; ``numeric_std`` arithmetic such as
``unsigned'("0011") + "0001"`` is unaffected.

eval
----

``eval`` evaluates a string containing a Python expression, in the default
session or another :ref:`session <python_bridge:sessions>`, and converts the
result to the VHDL type expected by the context, through one of these
functions (all aliased ``eval``):

* ``eval_integer``, returning ``integer``
* ``eval_real``, returning ``real``
* ``eval_string``, returning ``string``
* ``eval_integer_vector``, returning ``integer_vector``
* ``eval_real_vector``, returning ``real_vector``
* ``eval_integer_vector_ptr``, returning ``integer_vector_ptr_t``

.. code-block:: vhdl

    variable answer : integer;
    variable ratio : real;
    variable list : integer_vector_ptr_t;
  begin
    exec("from math import pi");
    answer := eval("6 * 7");
    ratio := eval("pi");
    list := eval("[1, 1, 2, 3, 5, 8]");

When the result type is not clear from the context (for example when it is
passed as an argument, or logged with ``info``), the explicit ``eval_<type>``
name selects the overload:

.. code-block:: vhdl

    info("pi = " & to_string(eval_real("pi")));

On NVC, GHDL and Questa, where the API is implemented by the VUnit Python
bridge, ``eval`` has more result types:

* ``eval_boolean``, returning ``boolean``. Only ``bool``/``numpy.bool_`` is
  accepted. It also makes the result of ``eval`` usable as a condition:
  ``if eval("model.is_done()") then``.
* ``eval_std_ulogic``, returning ``std_ulogic``.
* ``eval_std_ulogic_vector``, returning an unconstrained ``std_ulogic_vector``.
* ``eval_integer_array``, returning ``integer_array_t``, see
  :ref:`python_bridge:integer_array`.

``eval_boolean`` and ``eval_std_ulogic`` are aliased ``eval`` like the other
result types. ``eval_std_ulogic_vector`` and ``eval_integer_array`` are not,
since that would make ``check_equal(eval("17"), 17)`` and
``length(eval("[1, 2]"))`` ambiguous: use their explicit names.

``std_ulogic_vector``, ``signed`` and ``unsigned`` results are also available
as the procedures ``eval_std_ulogic_vector``, ``eval_signed`` and
``eval_unsigned``, that take the result as an ``out`` parameter. The width is
given by the actual, and a Python value that does not fit that width is an
error. ``signed`` and ``unsigned`` results are only available in the
procedure form, since a function cannot know the width of the result.

.. code-block:: vhdl

    variable byte : std_ulogic_vector(7 downto 0);
    variable level : signed(15 downto 0);
  begin
    eval_std_ulogic_vector("format(value, '08b')", byte);
    eval_signed("model.level()", level);

call, arg, kwarg and to_call_str
---------------------------------

``call`` calls a Python function (or a callable expression such as a dotted
name, ``"np.sum"``, or a method, ``"model.run"``) with up to 10 arguments,
built with ``arg`` (positional) and ``kwarg`` (keyword), and converts the
returned value like ``eval``. Like every other operation, it accepts an
optional trailing :ref:`session <python_bridge:sessions>` parameter, normally
given by name since it follows the positional arguments:

.. code-block:: vhdl

    variable gcd, count : integer;
    variable ratio : real;
  begin
    exec("from math import gcd as py_gcd");
    gcd := call("py_gcd", arg(35), arg(77), arg(119));
    ratio := call("round", arg(3.14159), kwarg("ndigits", 3));

    -- No return value: the procedure form of call
    call("print", arg(35), arg(77), arg(119));

``arg`` and ``kwarg`` accept these value types:

========================== ========================================================
VHDL                       Python
========================== ========================================================
``integer``                ``int``
``real``                   ``float``
``boolean``                ``bool``
``string``                 ``str``
``integer_vector``         ``list`` of ``int``
``real_vector``            ``list`` of ``float``
``integer_vector_ptr_t``   ``list`` of ``int``
``std_ulogic``              ``bool``, 1 and H give ``True``, 0 and L give ``False``
``unsigned``               ``int``, passed as ``arg_unsigned``/``kwarg_unsigned``
``signed``                 ``int``, passed as ``arg_signed``/``kwarg_signed``
``integer_array_t``        NumPy array, not on Riviera-PRO/Active-HDL
========================== ========================================================

An ``unsigned`` or ``signed`` value of any width becomes an exact Python
integer, so it is not limited to the range of a VHDL ``integer``. The two have
names of their own rather than ``arg`` overloads, since a string literal
belongs to every character array type and an overload would therefore make
``arg("hello")`` ambiguous. ``H`` and ``L`` are read as 1 and 0 in a
``std_ulogic``, ``unsigned`` or ``signed`` value; any other metavalue is an
error.

A value that cannot be converted is reported as a failure on
``python_logger``, and the argument becomes an expression raising the same
message in Python. The call it is used in therefore fails with that message as
well instead of being made without the argument, which is what would otherwise
happen when the logger is mocked and the simulation continues:

.. code-block:: text

    FAILURE - vunit_lib:python - arg cannot convert 'X'; expected '0', '1', 'L' or 'H'
    FAILURE - vunit_lib:python - eval("model(__vunit__.error("arg cannot convert 'X'; ..."))") failed:
    Traceback (most recent call last):
      ...
    RuntimeError: arg cannot convert 'X'; expected '0', '1', 'L' or 'H'

An aggregate or a literal does not select an overload by itself and needs a
qualified expression: ``arg(real_vector'(1.0, 2.0))``,
``arg(integer_vector'(1, 2, 3))``. There is no ``std_ulogic_vector`` value,
which would be ambiguous for the same reason as ``unsigned``. Such a value is
passed as a number or as the string of its characters:

.. code-block:: vhdl

    call("model.scale", arg_unsigned(unsigned(gain)));
    call("model.push", arg(to_string(slv)));

On NVC, GHDL and Questa, ``call`` returns the same types as ``eval``:
``call_boolean``, ``call_std_ulogic``, ``call_std_ulogic_vector``,
``call_integer_array``, ``call_string``, ``call_real_vector`` and
``call_integer_vector_ptr``, plus the procedures ``call_std_ulogic_vector``,
``call_signed`` and ``call_unsigned`` taking the result as an ``out``
parameter. All of the functions but ``call_std_ulogic_vector`` are aliased
``call``.

``to_call_str`` builds the Python call expression itself, as a string, which
is useful to embed a call inside a larger ``exec``/``eval`` string:

.. code-block:: vhdl

    exec("gcd = " & to_call_str("py_gcd", arg(35), arg(77)));

Every unused trailing argument of ``call``/``to_call_str`` defaults to an
ignored placeholder, so calls with fewer than 10 arguments need no padding.

Keyword argument groups
~~~~~~~~~~~~~~~~~~~~~~~~

Keyword arguments combined with ``&`` become a single argument, which makes it
possible to pass more than 10 keyword arguments and to build the keyword
arguments of a call in steps. ``null_arg`` is the identity of the operation and
only keyword arguments, or groups of them, can be combined:

.. code-block:: vhdl

    -- Calls plot(data, **dict(title="Step response", grid=True))
    call("plot", arg(data), kwarg("title", string'("Step response")) & kwarg("grid", true));

The group is passed to Python as ``**dict(...)`` and therefore keeps Python's
own rules: it must come after the positional arguments of the call and a
keyword must not be repeated within it. It uses one of the 10 argument slots,
no matter how many keyword arguments it holds.

import_run_script
------------------

``import_run_script`` imports the VUnit run script as a Python module, so
that functions and classes defined in it (for example a plot helper using
matplotlib) can be called from VHDL without duplicating them in a separate
file:

.. code-block:: vhdl

    import_run_script;
    exec("run.hello_world()");

    import_run_script("my_run_script");
    exec("my_run_script.hello_world()");

Without an explicit name, the module is named after the run script's file
name (without extension), so the run script is normally named ``run.py``.
Because the run script is imported as a module, it must be import-safe: code
that is only meant to run when the script is invoked directly (typically the
call to :meth:`vu.main() <vunit.ui.VUnit.main>`) must be behind
``if __name__ == "__main__":``; a run script without such a guard is
rejected before it is imported. Like the other operations, it takes an
optional trailing :ref:`session <python_bridge:sessions>` parameter.

import_module_from_file and to_py_list_str
--------------------------------------------

``import_module_from_file`` imports any Python file as a module by path (also
taking an optional :ref:`session <python_bridge:sessions>` parameter), and is
what ``import_run_script`` uses internally:

.. code-block:: vhdl

    import_module_from_file(join(tb_path(runner_cfg), "reference_model.py"), "reference_model");
    exec("reference_model.configure(gain=4)");

``to_py_list_str`` converts an ``integer_vector``, ``integer_vector_ptr_t`` or
``real_vector`` to the string representation of the equivalent Python list,
for use in ``exec``/``eval`` strings:

.. code-block:: vhdl

    exec("a_list = " & to_py_list_str(integer_vector'(1, 2, 3, 4)));
    check_equal(eval("sum(a_list)"), 10);

Type mapping
------------

* ``integer`` ↔ ``int``. Results outside the VHDL integer range fail.
* ``real`` ↔ ``float``. Strict: an ``int`` result is not accepted.
* ``string`` ↔ ``str``. UTF-8.
* ``boolean`` ↔ ``bool``/``numpy.bool_`` (Python bridge only).
* ``integer_vector`` ↔ ``list`` of ``int``.
* ``real_vector`` ↔ ``list`` of ``float`` (``call_real_vector`` needs the bridge).
* ``integer_vector_ptr_t`` ↔ ``list`` of ``int``.
* ``std_ulogic``/``std_ulogic_vector`` ↔ ``str``, one character per element
  out of ``U X 0 1 Z W L H -``, left to right (results only, Python bridge).
* ``signed``/``unsigned`` ↔ ``int`` (procedure results only, Python bridge).
* ``integer_array_t`` ↔ ``numpy.ndarray`` (Python bridge), see
  :ref:`python_bridge:integer_array`.

The types marked as needing the Python bridge are available on NVC, GHDL and
Questa, but not on Riviera-PRO/Active-HDL.

Results are strict: a value that does not fit the VHDL type, or is of the
wrong Python type, is an error. Values are never silently truncated or
wrapped.

Errors
------

Python exceptions, syntax errors, type errors and undefined names are
reported as failures on the ``python_logger`` logger (named
``vunit_lib:python``), including the Python traceback. The test fails and
stops like for any other failure. The logger can be mocked to test error
handling; when mocked, ``eval``/``call`` return a default value (``0``,
``0.0``, ``""`` or an empty vector, depending on the type) after the failure.

.. code-block:: text

    FAILURE - vunit_lib:python - eval("1 / 0") failed:
    Traceback (most recent call last):
      File "<eval #3>", line 1, in <module>
        1 / 0
        ~~^~~
    ZeroDivisionError: division by zero

Output of ``print`` is written to the simulator output and flushed after
every operation.

.. _python_bridge:integer_array:

integer_array_t and NumPy
--------------------------

.. note::

   ``integer_array_t`` values are transferred by the VUnit Python bridge and
   are therefore available on NVC, GHDL and Questa, but not on
   Riviera-PRO/Active-HDL.

An ``integer_array_t`` argument is transferred to Python and referred to by
the expression as a NumPy array of dtype ``int32``, so it can be reused in
several calls. The shape follows VUnit's indexing so that elements correspond
directly:

============= ================================ ===========================
Array         VHDL                             Python
============= ================================ ===========================
1D            ``get(a, i)``                    ``a[i]``, shape ``(length,)``
2D            ``get(a, x, y)``                 ``a[y, x]``, shape ``(height, width)``
3D            ``get(a, x, y, z)``              ``a[y, x, z]``, shape ``(height, width, depth)``
============= ================================ ===========================

``integer_array_t`` does not record its number of dimensions. An argument is
treated as 3D if its depth is larger than one, else as 2D if its height is
larger than one, else as 1D.

A returned array (or nested list of integers) becomes a new
``integer_array_t`` with the corresponding width, height and depth. Its
``bit_width`` and ``is_signed`` are those of the argument, if the function
returns one of its ``integer_array_t`` arguments (possibly modified in
place), else given by the dtype: ``bool`` is 1 bit unsigned, ``int8``/``uint8``
8 bit, ``int16``/``uint16`` 16 bit and all other integer dtypes 32 bit
signed. All values must fit that word size, otherwise the call fails.
Floating point arrays are rejected; convert them explicitly with ``astype``.
As usual, the returned ``integer_array_t`` is owned by the caller and can be
freed with ``deallocate``.

exec_file
---------

``exec_file`` executes a Python file (where the Python bridge implements the
API: NVC, GHDL and Questa), with the equivalent of

.. code-block:: python

    with open(path, encoding="utf-8") as file:
        source = file.read()
    exec(compile(source, str(path), "exec"), namespace, namespace)

which means that tracebacks show the real file name and line numbers,
``__file__`` is set to the absolute path of the file while it executes (and
restored afterwards), and the directory of the file is added to ``sys.path``
while it executes so that it can import sibling modules without setting
``PYTHONPATH``. Imports are therefore expected at the top level of the file.
Executing the same file twice executes it twice.

A relative file name is relative to the directory of the testbench file
(``tb_path``); an absolute path is used as given. Like the other operations,
it takes an optional trailing :ref:`session <python_bridge:sessions>`
parameter.

.. _python_bridge:semantics:

Semantics to be aware of
-------------------------

.. important::

   * ``eval``/``eval_<type>`` are declared ``impure`` since they always read
     state from the Python interpreter.
   * Errors are reported as failures on the ``python_logger`` logger,
     including the Python traceback, rather than aborting the simulation.
   * ``python_setup`` and ``python_cleanup`` are optional, see
     :ref:`python_bridge:setup_and_cleanup`. ``python_cleanup`` does not
     finalize the interpreter.
   * ``real`` results have no float32 range limit: VHDL ``real`` is double
     precision where the Python bridge implements the API, so any finite
     Python ``float`` (also double precision) is in range. A value that is not
     finite, such as ``float("inf")`` or ``float("nan")``, has no VHDL ``real``
     representation and is reported as a failure.
   * ``string`` arguments are passed to Python double-quoted verbatim: a quote
     or backslash inside the string is not escaped, so it must be avoided or
     already be valid inside a Python double-quoted string.

.. _python_bridge:other_simulators:

Other simulators
-----------------

Riviera-PRO/Active-HDL (VHPI) implement ``python_ffi_pkg`` with a VHPI
application, built from the C sources in :vunit_file:`vunit/vhdl/python/src
<vunit/vhdl/python/src>` with their ``ccomp`` driver. :meth:`add_python()
<vunit.ui.VUnit.add_python>` builds the application under the output path
(``<output path>/<simulator>/libraries``) the first time it is called and
rebuilds it when the sources, the Python running VUnit or the simulator
installation change, so a run script needs nothing beyond :meth:`add_python()
<vunit.ui.VUnit.add_python>`.

This application differs from the Python bridge in a few ways: only the
default session exists, the operations implemented by the bridge
(``integer_array_t`` values, the ``boolean``, ``std_ulogic``, vector and
``integer_array_t`` results, ``exec_file``) report that they require NVC, GHDL
or Questa, a Python error stops the simulation with the message printed by the
application rather than through ``python_logger``, and ``real`` values outside
the single precision float range are rejected.

See :vunit_example:`➚ examples/vhdl/embedded_python <vhdl/embedded_python>` for
a complete example covering all three simulator families.

Its ``tb_example.vhd`` has a test case for each part of the API: ``exec`` and
``eval`` with the types they convert, calls with positional, keyword and
keyword group arguments, a 20 register status dump, wide
``arg_unsigned``/``arg_signed`` and ``std_ulogic`` argument values, a 2-D
``integer_array_t`` image transposed by NumPy, the result types of ``eval`` and
``call``, Python files executed with ``exec_file`` or imported with
``import_module_from_file``, two models loaded into a session each, and a
Python model failing with ``python_logger`` mocked. Its last test case drives
``python_model``, a verification component whose behaviour is the Python
function in ``python_model.py`` rather than VHDL.

.. automodule:: vunit.python_bridge.foreign_application

.. _python_bridge:native:

How it works (NVC, GHDL and Questa)
------------------------------------

For NVC, GHDL and Questa, the interpreter is embedded in the simulator process
by a small C library, the VUnit Python bridge (:vunit_file:`vunit/python_bridge/native
<vunit/python_bridge/native>`). NVC and GHDL call it through VHPIDIRECT;
Questa/ModelSim calls it through the FLI, using the front end in
:vunit_file:`native/fli.c <vunit/python_bridge/native/fli.c>` that converts the
FLI parameters of one foreign subprogram per entry point. The generated VHDL
and everything above it is the same for all three. The interpreter is started
on first use, is never restarted within a simulation, and uses no signal
handlers of its own.

Linux
  The bridge is compiled from source against the Python running VUnit the
  first time :meth:`add_python() <vunit.ui.VUnit.add_python>` is called, and
  cached in ``<output path>/python_bridge``. It is rebuilt automatically when
  the source, the Python version or the Python installation changes. For
  Questa the FLI front end is compiled in too, against the ``mti.h`` of the
  simulator, and the simulator installation is part of the cache key. VUnit
  ships no prebuilt Linux library.

Windows
  For NVC and GHDL, VUnit ships DLLs built with MSVC for each supported Python
  minor version (``vunit/python_bridge/bin``). The matching DLL is copied to
  the output path and nothing is compiled. A development checkout of VUnit
  does not contain the DLLs; they can be built with
  ``tools/build_python_bridge.py`` from an MSVC developer prompt. For Questa
  the library must be linked against the simulator's ``mtipli``, so it is
  built on first use with the MinGW GCC bundled with Questa, against the
  headers and the import library of the Python running VUnit. That build is
  untested.

The bridge uses the full (version specific) CPython ABI rather than the
Stable ABI since embedding the interpreter in the environment VUnit runs in
requires the ``PyConfig`` initialization API, which is not part of the
limited API.

VUnit makes the simulator find the library automatically. NVC is given a
``--load`` option. GHDL gets the library directory in its dynamic library
search path, plus a linker search path for the ahead-of-time compiled llvm
and gcc backends. The FLI attributes generated for Questa name the library by
absolute path, and the vsim processes VUnit starts are given
``-noautoldlibpath`` on Linux so that the C++ runtime Questa bundles, which is
often older than the one the Python extension modules of the environment
(NumPy) were built against, does not take precedence over the one of the
system. No simulator options need to be set by the user.

Tested configurations
~~~~~~~~~~~~~~~~~~~~~~

========================== ========================================================
Simulator                  Linux
========================== ========================================================
NVC                        1.22 (and 1.23-devel)
GHDL mcode                 6.0.0, 7.0.0-dev
GHDL llvm-jit              6.0.0, 7.0.0-dev
GHDL llvm                  6.0.0, 7.0.0-dev
GHDL gcc                   6.0.0, 7.0.0-dev
Questa (FLI)               Altera Starter FPGA Edition 2025.3
========================== ========================================================

On Windows, CI tests NVC 1.22 and GHDL mcode (nightly) with Python 3.10, 3.12
and 3.14.

Questa is tested manually on Linux and is not covered by CI; the Windows build
of its bridge library is untested. Riviera-PRO/Active-HDL (VHPI) is not tested
at all.
