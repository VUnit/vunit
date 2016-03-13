.. _cli:

Command Line Interface
======================
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
-----

.. argparse::
   :ref: vunit.vunit_cli._parser_for_documentation
   :prog: run.py

Example Session
---------------
The :vunit_example:`VHDL User Guide Example <vhdl/user_guide/>` can be run to produce the following output:

.. code-block:: console
   :caption: List all tests

   > python run.py -l
   lib.tb_example.all
   lib.tb_example_many.test_pass
   lib.tb_example_many.test_fail
   Listed 3 tests

.. code-block:: console
   :caption: Run all tests

   > python run.py -v lib.tb_example*
   Running test: lib.tb_example.all
   Running test: lib.tb_example_many.test_pass
   Running test: lib.tb_example_many.test_fail
   Running 3 tests

   running lib.tb_example.all
   Hello World!
   pass( P=1 S=0 F=0 T=3) lib.tb_example.all (0.1 seconds)

   running lib.tb_example.test_pass
   This will pass
   pass (P=2 S=0 F=0 T=3) lib.tb_example_many.test_pass (0.1 seconds)

   running lib.tb_example.test_fail
   Error: It fails
   fail (P=2 S=0 F=1 T=3) lib.tb_example_many.test_fail (0.1 seconds)

   ==== Summary =========================================
   pass lib.tb_example.all            (0.1 seconds)
   pass lib.tb_example_many.test_pass (0.1 seconds)
   fail lib.tb_example_many.test_fail (0.1 seconds)
   ======================================================
   pass 2 of 3
   fail 1 of 3
   ======================================================
   Total time was 0.3 seconds
   Elapsed time was 0.3 seconds
   ======================================================
   Some failed!

.. code-block:: console
   :caption: Run a specific test

   > python run.py -v lib.tb_example.all
   Running test: lib.tb_example.all
   Running 1 tests

   Starting lib.tb_example.all
   Hello world!
   pass (P=1 S=0 F=0 T=1) lib.tb_example.all (0.1 seconds)

   ==== Summary ==========================
   pass lib.tb_example.all (0.9 seconds)
   =======================================
   pass 1 of 1
   =======================================
   Total time was 0.9 seconds
   Elapsed time was 1.2 seconds
   =======================================
   All passed!

Opening a Test Case in Simulator GUI
------------------------------------
Sometimes the textual error messages and logs are not enough to
pinpoint the error and a test case needs to be opened in the GUI for
visual debugging using single stepping, breakpoints and wave form
viewing. VUnit makes it easy to open a test case in the GUI by having
a ``-g/--gui`` command line flag:

.. code-block:: console

   > python run.py --gui my_test_case &

This launches a simulator GUI window with the top level for the
selected test case loaded and ready to run. Depending on the simulator
a help text is printed were a few TCL functions are pre-defined:

.. code-block:: tcl

   # List of VUnit commands:
   # vunit_help
   #   - Prints this help
   # vunit_load
   #   - Load design with correct generics for the test
   # vunit_run
   #   - Run test

The test bench has already been loaded with the ``vunit_load``
command. Breakpoints can now be set and signals added to the log or to
the waveform viewer manually by the user. The test case is then run
using the ``vunit_run`` command. Recompilation can be performed
without closing the GUI by running ``run.py`` with the ``--compile``
flag in a separate terminal. To re-run the test after compilation in
ModelSim:

.. code-block:: tcl

  restart -f
  vunit_run

.. _continuous_integration:

Continuous Integration Environment
----------------------------------
VUnit is easily utilized with continuous integration environments such as
`Jenkins`_. Once a project ``run.py`` has been setup, tests can be run in a
headless environment with standardized xUnit style output to a file.

.. code-block:: console
   :caption: Execute VUnit tests on CI server with XML output

    python run.py --xunit-xml test_output.xml

After tests have finished running, the ``test_output.xml`` file can be parsed
using standard xUnit test parsers such as `Jenkins xUnit Plugin`_.

.. _Jenkins: http://jenkins-ci.org/
.. _Jenkins xUnit Plugin: http://wiki.jenkins-ci.org/display/JENKINS/xUnit+Plugin

.. _simulator_selection:

Simulator Selection
-------------------
VUnit automatically detects which simulators are available on the
``PATH`` environment variable and by default selects the first one
found. For people who have multiple simulators installed the
``VUNIT_SIMULATOR`` environment variable can be set to one of
``activehdl``, ``rivierapro``, ``ghdl`` or ``modelsim`` to explicitly
specify which simulator to use.

In addition to VUnit scanning the ``PATH`` the simulator executable
path can be explicitly configured by setting a
``VUNIT_<SIMULATOR_NAME>_PATH`` environment variable.

.. code-block:: console
   :caption: Explicitly set path to GHDL executables

   VUNIT_GHDL_PATH=/opt/ghdl/bin
