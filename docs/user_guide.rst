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
with the ``test_runner_cleanup`` call.

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


The above example code can be found in :vunit_example:`vhdl/user_guide`.

.. _sv_test_benches:

SystemVerilog Test Benches
--------------------------
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

The above example code can be found in :vunit_example:`verilog/user_guide`.

.. _test_bench_scanning:

Scanning for Test Benches
-------------------------
VUnit will recognize a module or entity as a test bench and run it if
it has a ``runner_cfg`` generic or parameter. A SystemVerilog test
bench using the ``TEST_SUITE`` macro will have a ``runner_cfg``
parameter created by the macro and thus match the criteria.

A warning will be given if the test bench entity or module name does
not match the pattern ``tb_*`` or ``*_tb``.

A warning will be given if the name *does* match the above pattern but
lacks a ``runner_cfg`` generic or parameter preventing it to be run
by VUnit.


Special generics/parameters
---------------------------
A VUnit test bench can have several special generics/parameters.
Optional generics are filled in automatically by VUnit if detected on
the test bench.

- ``runner_cfg : string``

  Required by VUnit to pass private information between Python and the HDL test runner

- ``output_path : string``

  Optional path to the output directory of the current test.
  This is useful to create additional output files that can be checked
  after simulation by a **post_check** Python function.

- ``tb_path : string``

  Optional path to the directory containing the test bench.
  This is useful to read input data with a known location relative to
  the test bench location.

.. _examples:

Examples
--------
There are many examples demonstrating more specific usage of VUnit listed below:

:vunit_example:`VHDL User Guide Example <vhdl/user_guide/>`
  The most minimal VUnit VHDL project covering the basics of this user
  guide.

:vunit_example:`SystemVerilog User Guide Example <verilog/user_guide/>`
  The most minimal VUnit SystemVerilog project covering the basics of
  this user guide.

:vunit_example:`VHDL UART Example <vhdl/uart/>`
  A more realistic test bench of an UART to show VUnit VHDL usage on a
  typical module.  In addition to the normal ``run.py`` it also
  contains a ``run_with_preprocessing.py`` to demonstrate the benefit
  of location and check preprocessing.

:vunit_example:`SystemVerilog UART Example <verilog/uart/>`
  A more realistic test bench of an UART to show VUnit SystemVerilog
  usage on a typical module.

:vunit_example:`Check Example <vhdl/check/>`
  Demonstrates the VUnit check library.

:vunit_example:`Logging Example <vhdl/logging/>`
  Demonstrates VUnit's support for logging.

:vunit_example:`Array Example <vhdl/array/>`
  Demonstrates the ``array_t`` data type of ``array_pkg.vhd`` which
  can be used to handle dynamically sized 1D, 2D and 3D data as well
  as storing and loading it from csv and raw files.

:vunit_example:`Generating tests <vhdl/generate_tests/>`
  Demonstrates generating multiple test runs of the same test bench
  with different generic values. Also demonstrates use of ``output_path`` generic
  to create test bench output files in location specified by VUnit python runner.

:vunit_example:`Vivado IP example <vhdl/vivado/>`
  Demonstrates compiling and performing behavioral simulation of
  Vivado IPs with VUnit.

:vunit_example:`Communication library example <vhdl/com/>`
  Demonstrates the ``com`` message passing package which can be used
  to communicate arbitrary objects between processes.  Further reading
  can be found in the :ref:`com user guide <com_user_guide>`
