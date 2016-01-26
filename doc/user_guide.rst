User Guide
==========

Introduction
------------
The idea in VUnit is to have a single point of entry for compiling and
running all tests within a HDL project. Tests do not need to be
manually added to some list as they are automatically detected. There
is no need for maintaining a list of files in compile order or
manually re-compile selected files after they have been edited as
VUnit automatically determines the compile order as well as which
files to incrementally re-compile. This is achieved by having a
``run.py`` file for each project where libraries are defined into
which files are added using the VUnit Python interface. The ``run.py``
file then acts as a :ref:`command line utility <cli>` for compiling
and running tests within the VHDL project.

The Python interface of VUnit is exposed through the :class:`VUnit
<vunit.ui.VUnit>` class that can be imported directly from the
:mod:`vunit <vunit.ui>` module. Read :ref:`this <installing>` to make
VUnit module visible to Python.

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
respectively. A test bench can in iself be a single unamed test or
contain multiple named test cases. The command line interface supports
listing all tests found as well as running individual tests matching a
wildcard pattern. The Python API also supports running the same test
bench or test with multiple combinations of generic values.

There are many :ref:`example projects <examples>` demonstrating the
usage and capabilities of VUnit.

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

.. _cli:

Command Line Interface
----------------------
A :class:`VUnit <vunit.ui.VUnit>` object can be created from command
line arguments by using the :meth:`from_argv
<vunit.ui.VUnit.from_argv>` method effectively creating a custom
command line tool for running tests in the user project.  Source files
and libraries are added to the project by using methods on the VUnit
object. The configuration is followed by a call to the :meth:`main
<vunit.ui.VUnit.main>` method which will execute the function
specified by the command line arguments and exit the script. The added
source files are automatically scanned for test cases.

Usage
^^^^^

.. argparse::
   :ref: vunit.vunit_cli._parser_for_documentation
   :prog: run.py

.. _installing:

Installing
----------
To be able to import :class:`vunit.ui.VUnit` in your ``run.py`` script
you need to make it visible to Python or else the following error
occurs.

.. code-block:: console

   Traceback (most recent call last):
      File "run.py", line 2, in <module>
        from vunit import VUnit
   ImportError: No module named vunit

There are three methods to make VUnit importable in your ``run.py`` script.:

1. Install it in your Python environment using:

   .. code-block:: console

      > python setup.py install

2. Set the ``PYTHONPATH`` environment variable to include the path to
   the VUnit root directory containing this user guide. Note that you
   shouldn't point to the vunit directory within the root directory.

3. Add the following to your ``run.py`` file **before** the ``import vunit``
   statement:

   .. code-block:: python

      import sys
      sys.path.append("/path/to/vunit_root/")
      import vunit

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
  Demonstrates the VUnit check library..

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
  to communicate arbitrary objects between processes.

..
  @TODO Further reading can be found in the [com user guide](vunit/vhdl/com/user_guide.md)
