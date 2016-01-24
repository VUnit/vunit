.. _user_guide:

User Guide
==========

Introduction
------------
The idea in VUnit is to have a single point of entry for compiling and
running all tests within a HDL project. Tests do not need to be
manually added to some list as they are automatically detected. There
is no need for maintaining a list of files in compile order or
manually re-compile files after they have been edited as VUnit
automatically determines the compile order and which files to
re-compile after a modification.

A ``run.py`` file is created for the project where the :ref:`VUnit
Python interface <python_interface>` is used to add libraries and HDL
files. The ``run.py`` file then acts as a :ref:`command line utility
<cli>` for compiling and running tests within the project.

The command line interface supports listing all tests found as well as
running individual tests matching a wildcard pattern. The Python
interface also supports running a test bench or test for many
different combinations of generic values.

.. code-block:: python
   :caption: Example ``run.py`` file.

   from vunit import VUnit

   # Create VUnit instance by parsing command line arguments
   vu = VUnit.from_argv()

   # Create library 'lib'
   lib = vu.add_library("lib")

   # Add all files ending in .vhd in current working directory
   lib.add_source_files("*.vhd")

   # Run vunit function
   vu.main()

Test benches are written using supporing libraries in :ref:`VHDL
<vhdl_test_benches>` and :ref:`SystemVerilog <sv_test_benches>`
respectively. A test bench can in iself be a single unnamed test or
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

From ``tb_example.vhd`` a single test case named ``lib.tb_example`` is
created.

It is also possible to put multiple tests in a single test
bench that are each run in individual simulations. Putting multiple
tests in the same test bench is a good way to share a common test
environment.

.. literalinclude:: ../examples/vhdl/user_guide/tb_example_many.vhd
   :caption: VHDL test bench with multiple tests: `tb_example_many.vhd`
   :language: vhdl
   :lines: 7-

From ``tb_example_many.vhd`` two test cases are created:

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

From ``tb_example.vhd`` three test cases are created:

* ``lib.tb_example.Test that pass``
* ``lib.tb_example.Test that fail``
* ``lib.tb_example.Test that timeouts``

Each test is run in an individual simulation. Putting multiple tests
in the same test bench is a good way to share a common test
environment.

The above example code can be found in :vunit_example:`verilog/user_guide`.

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

:vunit_example:`Generateing tests <vhdl/generate_tests/>`
  Demonstrates generating multiple test runs of the same test bench
  with different generic values.

:vunit_example:`Vivado IP example <vhdl/vivado/>`
  Demonstrates compiling and performing behavioral simulation of
  Vivado IPs with VUnit.

:vunit_example:`Communication library example <vhdl/com/>`
  Demonstrates the ``com`` message passing package which can be used
  to communicate arbitrary objects between processes.  Further reading
  can be found in the :ref:`com user guide <com_user_guide>`
