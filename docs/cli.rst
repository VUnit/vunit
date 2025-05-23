.. _cli:

Command Line Interface
######################

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
=====

.. argparse::
   :ref: vunit.vunit_cli._parser_for_documentation
   :prog: run.py

Example Session
===============

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

   > python run.py
   Re-compile not needed

   (09:40:59) Starting lib.tb_example.all
   Output file: C:\vunit\examples\vhdl\user_guide\vunit_out\test_output\lib.tb_example.all_7b5933c73ddb812488c059080644e9fd58c418d9\output.txt
   pass (P=1 S=0 F=0 T=3) lib.tb_example.all (0.5 s)                 

   (09:40:59) Starting lib.tb_example_many.test_pass
   Output file: C:\vunit\examples\vhdl\user_guide\vunit_out\test_output\lib.tb_example_many.test_pass_aff64431373db20d8bbba18c28096f449861ccbe\output.txt
   pass (P=2 S=0 F=0 T=3) lib.tb_example_many.test_pass (0.5 s)      

   (09:41:00) Starting lib.tb_example_many.test_fail
   Output file: C:\vunit\examples\vhdl\user_guide\vunit_out\test_output\lib.tb_example_many.test_fail_d8956871e3b3d178e412e37587673fe9df648faf\output.txt
   Seed for lib.tb_example_many.test_fail: 7efb6d37186ac077      
   C:\vunit\examples\vhdl\user_guide\tb_example_many.vhd:26:9:@0ms:(assertion error): It fails
   ghdl:error: assertion failed                                                                 
   ghdl:error: simulation failed
   fail (P=2 S=0 F=1 T=3) lib.tb_example_many.test_fail (0.5 s)

   ==== Summary =========================================
   pass lib.tb_example.all            (0.5 s)
   pass lib.tb_example_many.test_pass (0.5 s)                                                                                                                  
   fail lib.tb_example_many.test_fail (0.5 s)
   ======================================================                                                                                                      
   pass 2 of 3
   fail 1 of 3
   ======================================================
   Total time was 1.5 s
   Elapsed time was 1.5 s
   ======================================================
   Some failed!

By default, test output is shown only for failing tests. To display output for all tests, use the ``-v`` option. The example below demonstrates this,
while also selecting a subset of tests using a test pattern.

.. code-block:: console
   :caption: Run specific test(s) matching a pattern


   > python run.py -v lib.tb_example_many*
   Re-compile not needed

   Running test: lib.tb_example_many.test_pass
   Running test: lib.tb_example_many.test_fail
   Running 2 tests

   (09:57:18) Starting lib.tb_example_many.test_fail
   Output file: C:\vunit\examples\vhdl\user_guide\vunit_out\test_output\lib.tb_example_many.test_fail_d8956871e3b3d178e412e37587673fe9df648faf\output.txt
   Seed for lib.tb_example_many.test_fail: 2c14af95ae82a231
   C:\vunit\examples\vhdl\user_guide\tb_example_many.vhd:26:9:@0ms:(assertion error): It fails
   ghdl:error: assertion failed
   ghdl:error: simulation failed
   fail (P=0 S=0 F=1 T=2) lib.tb_example_many.test_fail (3.2 s)

   (09:57:22) Starting lib.tb_example_many.test_pass
   Output file: C:\vunit\examples\vhdl\user_guide\vunit_out\test_output\lib.tb_example_many.test_pass_aff64431373db20d8bbba18c28096f449861ccbe\output.txt
   Seed for lib.tb_example_many.test_pass: 30e3764e6f87ca85
   C:\vunit\examples\vhdl\user_guide\tb_example_many.vhd:23:9:@0ms:(report note): This will pass
   simulation stopped @0ms with status 0
   pass (P=1 S=0 F=1 T=2) lib.tb_example_many.test_pass (0.5 s)

   ==== Summary =========================================
   pass lib.tb_example_many.test_pass (0.5 s)
   fail lib.tb_example_many.test_fail (3.2 s)
   ======================================================
   pass 1 of 2
   fail 1 of 2
   ======================================================
   Total time was 3.6 s
   Elapsed time was 3.7 s
   ======================================================
   Some failed!

Note that the order of test execution has changed - the failing test is now run first. VUnit reorders tests based on
previous results and recent code changes to achieve two main goals:

1. Prioritize likely failures - Tests more likely to fail are executed earlier to provide faster feedback. In this case, ``lib.tb_example_many.test_fail``
   has a history of failing, and no relevant code changes have been made, so it is assumed to fail again and is run first.
2. Load balancing - When tests are executed in parallel using the ``-p`` option, VUnit distributes them across threads to minimize to total execution time.

Opening a Test Case in Simulator GUI
====================================

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

   # vunit_help
   #   - Prints this help
   # vunit_load [vsim_extra_args]
   #   - Load design with correct generics for the test
   #   - Optional first argument are passed as extra flags to vsim
   # vunit_user_init
   #   - Re-runs the user defined init file
   # vunit_run
   #   - Run test, must do vunit_load first
   # vunit_compile
   #   - Recompiles the source files
   # vunit_restart
   #   - Recompiles the source files
   #   - and re-runs the simulation if the compile was successful

The test bench has already been loaded with the ``vunit_load``
command. Breakpoints can now be set and signals added to the log or to
the waveform viewer manually by the user. The test case is then run
using the ``vunit_run`` command. Recompilation can be performed
without closing the GUI by running ``vunit_compile``. It is also
possible to perform ``run.py`` with the ``--compile`` flag in a
separate terminal.

Test Output Paths
=================

VUnit creates a separate output directory for each test to provide
isolation. The test output paths are located under
``OUTPUT_PATH/test_output/``. The test names have been washed of any
unsuitable characters and a hash has been added as a suffix to ensure
uniqueness.

On Windows the paths can be shortened to avoid path length
limitations. This behavior can be controlled by setting the relevant
:ref:`environment variables <test_output_envs>`.

To get the exact test name to test output path mapping the file
``OUTPUT_PATH/test_output/test_name_to_path_mapping.txt`` can be used.
Each line contains a test output path followed by a space seperator
and then a test name.

.. note::
   When using the ``run_all_in_same_sim`` pragma all tests within the
   test bench share the same output folder named after the test bench.

.. _environment_variables:

Environment Variables
=====================

.. _simulator_selection:

Simulator Selection
-------------------
VUnit automatically detects which simulators are available on the
``PATH`` environment variable and by default selects the first one
found. For people who have multiple simulators installed the
``VUNIT_SIMULATOR`` environment variable can be set to one of
``activehdl``, ``rivierapro``, ``ghdl``, ``nvc```, or ``modelsim`` to
specify which simulator to use. ``modelsim`` is used for both ModelSim
and Questa as VUnit handles these simulators identically.

In addition to VUnit scanning the ``PATH`` the simulator executable
path can be explicitly configured by setting a
``VUNIT_<SIMULATOR_NAME>_PATH`` environment variable.

.. code-block:: console
   :caption: Explicitly set path to GHDL executables

   VUNIT_GHDL_PATH=/opt/ghdl/bin

Simulator Specific
------------------

- ``VUNIT_MODELSIM_INI`` By default VUnit copies the *modelsim.ini*
  file from the tool install folder as a starting point. Setting this
  environment variable selects another *modelsim.ini* file as the
  starting point allowing the user to customize it.

.. _test_output_envs:

Test Output Path Length
-----------------------
- ``VUNIT_SHORT_TEST_OUTPUT_PATHS`` Unfortunately file system paths
  are still practically limited to 260 characters on Windows. VUnit
  tries to limit the length of the test output paths on Windows to
  avoid this limitation but still includes as much of the test name
  name as possible leaving a margin of 100 characters. VUnit however
  cannot forsee user specific test output file lengths and this
  environment variable can be set to minimize output path lengths on
  Windows. On other operating systems this limitation is not relevant.

- ``VUNIT_TEST_OUTPUT_PATH_MARGIN`` Can be used to change the test
  output path margin on Windows. By default the test output path is
  shortened to allow a 100 character margin.

Language revision selection
---------------------------

The VHDL revision can be specified through the :ref:`python_interface`
(see :class:`vunit.ui.VUnit`).
Alternatively, environment variable ``VUNIT_VHDL_STANDARD`` can be set to
``93``|``1993``, ``02``|``2002``, ``08``|``2008`` (default) or ``19``|``2019``.

.. IMPORTANT::
  Note that VHDL revision 2019 is unsupported by most vendors, and support of VHDL 2008 features is uneven.
  Check the documentation of the simulator before using features requiring revisions equal or newer than 2008.

.. _json_export:

JSON Export
===========

VUnit supports exporting project information through the ``--export-json`` command
line argument. A JSON file is written containing the list of all files
added to the project as well as a list of all tests. Each test has a
mapping to its source code location.

The feature can be used for IDE-integration where the IDE can know the
path to all files, the library mapping of files and the source code
location of all tests.

The JSON export file has three top level values:

  - ``export_format_version``: The `semantic <https://semver.org/>`_ version of the format
  - ``files``: List of project files. Each file item has ``file_name`` and ``library_name``.
  - ``tests``: List of tests. Each test has ``attributes``, ``location`` and ``name``
    information. Attributes is the list of test attributes. The ``location`` contains the file name as well as
    the offset and length in characters of the symbol that defines the test. ``name`` is the name of the test.

.. code-block:: json
   :caption: Example JSON export file (file names are always absolute but the example has been simplified)

   {
       "export_format_version": {
           "major": 1,
           "minor": 0,
           "patch": 0
       },
       "files": [
           {
               "library_name": "lib",
               "file_name": "tb_example_many.vhd"
           },
           {
               "library_name": "lib",
               "file_name": "tb_example.vhd"
           }
       ],
       "tests": [
           {
               "attributes": {},
               "location": {
                   "file_name": "tb_example_many.vhd",
                   "length": 9,
                   "offset": 556
               },
               "name": "lib.tb_example_many.test_pass"
           },
           {
               "attributes": {},
               "location": {
                   "file_name": "tb_example_many.vhd",
                   "length": 9,
                   "offset": 624
               },
               "name": "lib.tb_example_many.test_fail"
           },
           {
               "attributes": {
                   ".attr": null
               },
               "location": {
                   "file_name": "tb_example.vhd",
                   "length": 18,
                   "offset": 465
               },
               "name": "lib.tb_example.all"
           }
       ]
   }


.. note:: Several tests may map to the same source code location if
          the user created multiple :ref:`configurations
          <configurations>` of the same basic tests.
