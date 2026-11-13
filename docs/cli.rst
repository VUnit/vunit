.. _cli:

Command Line Interface
######################

Creating a Project
==================

Run ``vunit create-project`` to create a starter ``run.py``. The project root defaults to the current directory; in an
interactive terminal, Tab completes directory paths. Enter library names one at a time; the first defaults to ``lib``.
Press Enter on a blank library name after the first entry, then enter source paths for the library shown in the prompt. When there are
multiple libraries, press Ctrl-L to cycle the active library without losing the path being typed. Press Enter on an empty
source path to review the project configuration. With redirected input, a line containing only the Ctrl-L control character
cycles libraries. Source directories include only their immediate files by default; Ctrl-R toggles recursive selection
for subsequent paths. With redirected input, a line containing only Ctrl-R toggles the mode. In an interactive terminal,
the available controls appear below the source prompt when supported, otherwise above it. With redirected input, they
appear above it. Press Tab to complete directories and HDL files relative to the project root;
when a directory completion is selected, press Tab again to browse inside it. Quoted paths, home directories,
and environment-variable paths are supported.

Run ``vunit create-testbench`` to generate a VHDL testbench, and enter the source and testbench paths when prompted.
In an interactive terminal, Tab completes paths for both initial and edited entries; press Tab on a selected directory
to browse inside it.
Alternatively, supply either or both paths using ``--source`` and ``--testbench``.
Enter the library containing the entity when prompted, or specify it with ``--library``; the default is ``work``.
The source must contain exactly one entity. The generated testbench instantiates it in that library, forwards
its generics, and connects its ports to signals. Existing files are not overwritten. Generic types, packages, and
subprograms, extended identifiers, and SystemVerilog sources are not supported.

Tests are named with ``--tests``, which takes one or more names. Quote names containing spaces; each argument is
one test and is used exactly as written, in the given order:

.. code-block:: console

    vunit create-testbench --source fifo.vhd --testbench tb_fifo.vhd --tests "reset behavior" "write and read"

Every generated test is marked with the ``.todo`` attribute and ends with an ``error`` call, so an unfinished test
fails instead of passing silently. Without ``--tests`` a single test named ``first_test`` is generated:

.. code-block:: vhdl

    while test_suite loop
      if run("first_test") then
        -- vunit: .todo
        error("Tests have yet to be added");
      end if;
    end loop;

``.todo`` is an ordinary VUnit attribute, so unfinished tests can be excluded with ``--without-attributes .todo``
or listed with ``--with-attributes .todo``. Remove the attribute and the ``error`` call when the test has been
implemented. Test names must be non-empty, unique, printable characters from the VHDL character set, and must not
contain double quotation marks, which VUnit cannot discover correctly in ``run("...")``.
Interactively, the first test name prompt defaults to ``first_test``; pressing Enter accepts it and moves on to the
review menu without further prompts. If another name is entered, later prompts end on a blank answer. In the review menu, choose ``Add test`` or ``Remove test`` (by name or
number) to edit the list; an empty list generates ``first_test``.

Input prompts start with ``>``; the current source library and directory mode are displayed separately.
Run ``vunit`` without a command in an interactive terminal to choose a command using completion and the arrow keys.
When invoked without options, both creation commands show a review menu before writing files. Choose a field to edit it,
select ``Preview`` to inspect the generated file, then select ``Create`` or ``Cancel``. In a terminal, use the arrow keys
to select an action; redirected input accepts the action name or number.

Creation Options
================

Pass options to create directly, without the review menu. Missing values with interactive defaults use those defaults;
other missing values are prompted for. For example:

.. code-block:: console

    vunit create-project --root my_project --library rtl --source rtl src/top.vhd --recursive-source rtl src/design
    vunit create-testbench --source device.vhd --testbench tb_device.vhd --library rtl

For ``create-project``, ``--root`` defaults to the current directory and repeatable ``--library`` defaults to ``lib``.
Repeat ``--source LIBRARY PATH`` for files or non-recursive directories and ``--recursive-source LIBRARY PATH`` for
recursive directories. Source paths are relative to the project root unless absolute. If no source option is supplied,
the source path prompt is shown; use ``--no-sources`` to create an empty project without prompting. Every source library
must be declared with ``--library`` or be the default ``lib``.

For ``create-testbench``, ``--source`` and ``--testbench`` provide the paths, and ``--library`` defaults to ``work``.
Missing paths are prompted for.

Previewing
==========

Add ``--preview`` to ``create-project`` or ``create-testbench`` to list the files that would be created without writing
anything. Interactive and option-driven use work as before; the final ``Create`` action is replaced by ``Preview``.
Add ``--show-content`` to include the generated source.

.. code-block:: console

    vunit create-testbench --preview --source device.vhd --testbench tb_device.vhd
    Files to create:
      tb_device.vhd

    No files written.

``--preview --json`` prints ``{"files": [{"path": ..., "action": "create"}]}`` (plus ``content`` with
``--show-content``) as the only output on stdout; errors go to stderr with exit code 1. ``--json`` never prompts, so
``create-testbench`` requires ``--source`` and ``--testbench``, and ``create-project`` requires ``--source``,
``--recursive-source`` or ``--no-sources``. The preview uses the same validation and rendering as creation, so a
destination that already exists is reported as an error, just as it is when creating.

Programmatic Generation
=======================

The generators can also be used without the interactive interface. Each accepts a configuration dictionary:

.. code-block:: python

   from vunit.app.generation import project, testbench

   project_config = {
       "root": "my_project",
       "libraries": {"lib": [{"path": "src", "recursive": True}]},
   }
   testbench_config = {"source": "device.vhd", "testbench": "tb_device.vhd", "library": "work", "tests": ["reset"]}

   project_preview = project.preview(project_config)
   testbench_preview = testbench.preview(testbench_config)
   project_summary = project.generate(project_config)
   testbench_summary = testbench.generate(testbench_config)

Project source paths are relative to the project root unless absolute. Each source can be a file or directory;
``recursive`` defaults to ``False``. At least one library is required, but a library may have no sources. The
testbench library defaults to ``work`` and ``tests`` is an optional list of test names (see above). Paths may be strings or :class:`pathlib.Path` objects.

``preview`` validates the configuration and returns a JSON-serializable dictionary with a ``files`` list. Each item
contains the destination ``path`` and generated ``content``; no files or directories are created. ``generate``
validates again, creates the files, and returns a JSON-serializable dictionary containing ``command``,
``files_created`` (a list of paths), and command-specific ``details``. Paths in results are strings. Project
results use resolved absolute paths; testbench paths retain their supplied form, except for home-directory expansion
in output paths.

Neither operation prompts or prints. Invalid configurations raise an exception, such as ``ValueError`` for an invalid
name or an existing destination, or ``OSError`` for a filesystem error. Existing output files are never overwritten,
including when another process creates the destination between validation and creation.

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
