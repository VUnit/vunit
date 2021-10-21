.. _user_guide:

User Guide
==========

Introduction
------------

VUnit is invoked by a user-defined project specified in a Python
script.  At minimum, a VUnit project consists of a set of HDL source
files mapped to libraries. The project serves as single point of entry
for compiling and running all tests within an HDL project. VUnit
provides automatic :ref:`scanning <test_bench_scanning>` for unit
tests (test benches), automatic determination of compilation order,
and incremental recompilation of modified sources.

The top level Python script is typically named ``run.py``.
This script is the entry point for executing VUnit.
The script defines the location for each HDL source
file in the project, the library that each source file belongs to, any
external (pre-compiled) libraries, and special settings that may be required
in order to compile or simulate the project source files. The :ref:`VUnit
Python interface <python_interface>` is used to create and manipulate the VUnit
project within the ``run.py`` file.

Since the VUnit project is defined by a Python script, the full functionality
of Python is available to create dynamic rules to specify the files
that should be included in the project. For example, HDL files may be
recursively included from a directory structure based on a filename pattern.
Other Python packages or modules may be imported in order to setup the project.

Once the files for a project have been included, the :ref:`command line
interface <cli>` can then be used to perform a variety of actions on the
project. For example, listing all tests discovered, or running individual tests
matching a wildcard pattern. The Python interface also supports running a test
bench or test for many different combinations of generic values.

.. code-block:: python
   :caption: Example ``run.py`` file.

   from vunit import VUnit

   # Create VUnit instance by parsing command line arguments
   vu = VUnit.from_argv()

   # Optionally add VUnit's builtin HDL utilities for checking, logging, communication...
   # See http://vunit.github.io/hdl_libraries.html.
   vu.add_vhdl_builtins()
   # or
   # vu.add_verilog_builtins()

   # Create library 'lib'
   lib = vu.add_library("lib")

   # Add all files ending in .vhd in current working directory to library
   lib.add_source_files("*.vhd")

   # Run vunit function
   vu.main()

Test benches are written using supporting libraries in :ref:`VHDL
<vhdl_test_benches>` and :ref:`SystemVerilog <sv_test_benches>`
respectively. A test bench can in itself be a single unnamed test or
contain multiple named test cases.

There are many :ref:`example projects <examples>` demonstrating the
usage and capabilities of VUnit.

VUnit supports many simulators. Read about how they are detected and
how to choose which one to use :ref:`here <simulator_selection>`.

.. _vhdl_test_benches:

VHDL Test Benches
-----------------

.. HINT::

   Example code available at :vunit_example:`vhdl/user_guide`.

In its simplest form a VUnit VHDL test bench looks like this:

.. literalinclude:: ../examples/vhdl/user_guide/tb_example.vhd
   :caption: Simplest VHDL test bench: `tb_example.vhd`
   :language: vhdl
   :lines: 7-

From ``tb_example.vhd`` a single test case named
``lib.tb_example.all`` is created.

This example also outlines what you have to do with existing testbenches to
make them VUnit compatible. Include the VUnit context, add the ``runner_cfg``
generic, and wrap your existing code in your main controlling process with
the calls to ``test_runner_setup`` and ``test_runner_cleanup``. Remember to
remove your testbench termination code, for example calls to ``std.env.finish``,
end of simulation asserts, or similar. A VUnit testbench must be terminated
with the ``test_runner_cleanup`` call. The procedures described here are part
of the VUnit run library. More information on this library can be found in its
:ref:`user guide <run_library>`.

It is also possible to put multiple tests in a single test
bench that are each run in individual, independent, simulations.
Putting multiple tests in the same test bench is a good way to share a common
test environment.

.. literalinclude:: ../examples/vhdl/user_guide/tb_example_many.vhd
   :caption: VHDL test bench with multiple tests: `tb_example_many.vhd`
   :language: vhdl
   :lines: 7-

From ``tb_example_many.vhd``'s ``run()`` calls, two test cases are created:

* ``lib.tb_example_many.test_pass``
* ``lib.tb_example_many.test_fail``

.. _sv_test_benches:

SystemVerilog Test Benches
--------------------------

.. HINT::

   Example code available at :vunit_example:`verilog/user_guide`.

In its simplest form a VUnit SystemVerilog test bench looks like this:

.. literalinclude:: ../examples/verilog/user_guide/tb_example.sv
   :caption: SystemVerilog test bench: `tb_example.sv`
   :language: verilog
   :lines: 7-

From ``tb_example.sv``'s ```TEST_CASE()`` macros, three test cases are created:

* ``lib.tb_example.Test that pass``
* ``lib.tb_example.Test that fail``
* ``lib.tb_example.Test that timeouts``

Each test is run in an individual simulation. Putting multiple tests
in the same test bench is a good way to share a common test
environment.

.. _test_bench_scanning:

Scanning for Test Benches
-------------------------

VUnit will recognize a module or entity as a test bench and run it if
it has a ``runner_cfg`` generic or parameter. A SystemVerilog test
bench using the ``TEST_SUITE`` macro will have a ``runner_cfg``
parameter created by the macro and thus match the criteria.

.. WARNING:: A warning will be given if:

   * The test bench entity or module name **does not match** the pattern
     ``tb_*`` or ``*_tb``.

   * The name **does match** the above pattern **but lacks** a ``runner_cfg``
     generic or parameter preventing it to be run by VUnit.

.. _special_generics:

Special generics/parameters
---------------------------

- [**required**] ``runner_cfg : string``, used by VUnit to pass private information
  between Python and the HDL test runner.

- [**optional**] ``output_path : string``, path to the output directory of the
  current test; this is useful to create additional output files that can
  be checked after simulation by a **post_check** Python function.

- [**optional**] ``tb_path : string``, path to the directory containing the test
  bench; this is useful to read input data with a known location relative to
  the test bench location.

.. HINT:: Optional generics/parameters are filled in automatically by VUnit if detected
   on the test bench.
