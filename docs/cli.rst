.. _cli:

Command Line Interface
======================
A :class:`VUnit <vunit.ui.vunit.VUnit>` object can be created from command
line arguments by using the :meth:`from_argv
<vunit.ui.vunit.VUnit.from_argv>` method effectively creating a custom
command line tool for running tests in the user project.  Source files
and libraries are added to the project by using methods on the VUnit
object. The configuration is followed by a call to the :meth:`main
<vunit.ui.vunit.VUnit.main>` method which will execute the function
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
-----------------
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

Simulator Specific Environment Variables
----------------------------------------

- ``VUNIT_MODELSIM_INI`` By default VUnit copies the *modelsim.ini*
  file from the tool install folder as a starting point. Setting this
  environment variable selects another *modelsim.ini* file as the
  starting point allowing the user to customize it.

.. _test_output_envs:

Test Output Path Length Environment Variables
---------------------------------------------
- ``VUNIT_SHORT_TEST_OUTPUT_PATHS`` Unfortunately file system paths
  are still practically limited to 260 characters on Windows. VUnit
  tries to limit the length of the test output paths on Windows to
  avoid this limitation but still includes as much of the test name
  name as possible leaving a margin of 100 characters. VUnit however
  cannot forsee user specifc test output file lengths and this
  environment variable can be set to minimize output path lengths on
  Windows. On other operating systems this limitation is not relevant.

- ``VUNIT_TEST_OUTPUT_PATH_MARGIN`` Can be used to change the test
  output path margin on Windows. By default the test output path is
  shortened to allow a 100 character margin.

.. _continuous_integration:

Continuous Integration (CI) Environment
---------------------------------------

Because VUnit features the functionality needed to realize continuous and automated testing of HDL code, it is a very valuable resource in continuous integration environments. Once a project ``run.py`` has been setup, tests can be run in a headless environment with standardized `Xunit <https://en.wikipedia.org/wiki/List_of_unit_testing_frameworks>`_ style output to a file; which allows dynamic interpretation of results avoiding custom (and error-prone) parsing of the logs.

.. code-block:: console
   :caption: Execute VUnit tests on CI server with XML output

    python run.py --xunit-xml test_output.xml

After tests have finished running, the ``test_output.xml`` file can be parsed
using standard xUnit test parsers such as `Jenkins xUnit Plugin <http://wiki.jenkins-ci.org/display/JENKINS/xUnit+Plugin>`_.

Furthermore, VUnit can be easily executed in many different platforms (either operating systems or architectures), because it is written in Python, which is an interpreted language. However, besides the sources and VUnit, a `HDL compiler/simulator <https://en.wikipedia.org/wiki/List_of_HDL_simulators>`_ is required in order to run the tests. Due to performance, all the HDL simulators are written in compiled languages, which makes the releases platform specific. I.e., each simulator needs to be specifically compiled for a given architecture and operating system. This might represent a burden for the adoption of continuous integration in hardware development teams, as it falls into the category of dev ops.

Nevertheless, thanks to the striking research about portable development environment solutions in the last decade, there are a bunch of alternatives to ease the path. The 'classic' approach is to use virtual machines with tools
such as `VirtualBox <https://www.virtualbox.org/>`_, `QEMU <https://www.qemu.org/>`_ or `VMware <https://www.vmware.com>`_. This is still an option, but for most uses cases sharing complete system images is overkill. Here, `containerization or operating-system-level virtualization <https://en.wikipedia.org/wiki/Operating-system-level_virtualization>`_ comes into the game. Without going into technical details, containers are a kind of lightweight virtual machines, and the most known product that uses such a technology is `Docker <https://docker.com>`_. Indeed, products such as `Vagrant <https://www.vagrantup.com/>`_ are meant to simplify the usage of virtual machines and/or containers by providing a common (black) box approach. In the end, there are enough open/non-open and free/non-free solutions for each user/company to choose the one that best fits their needs. From the hardware designer point-of-view, we 'just' need a box (no matter the exact underlying technology) that includes VUnit and a simulator.

Fortunately, contributors of project `GHDL <https://github.com/ghdl/ghdl>`_ provide ready-to-use docker images at `hub.docker.com/u/ghdl/dashboard <https://hub.docker.com/u/ghdl/dashboard/>`_. Some of these include not only GHDL but also VUnit:

* ``ghdl/ext:vunit``: Debian Stretch image with GHDL built from the latest commit of the master branch, and the latest release of VUnit installed through ``pip``.
* ``ghdl/ext:vunit-master``: Debian Stretch with GHDL built from the latest commit of the master branch, and the latest commit of VUnit from the master branch.

As a result, the burden for the adoption of continuous integration for VUnit users is reduced to using docker; which is available in GNU/Linux, FreeBSD, Windows and macOS, and is supported in most cloud services (`Travis CI <https://travis-ci.org/>`_, `AWS <https://aws.amazon.com/docker/>`_, `Codefresh <https://codefresh.io/>`_, etc.) or CI frameworks (`Jenkins <https://jenkins.io/>`_, `Drone <https://drone.io/>`_, `GitLab Runner <https://docs.gitlab.com/runner/>`_, etc.).

For example, script :vunit_file:`examples/vhdl/docker_runall.sh <examples/vhdl/docker_runall.sh>` shows how to run all the VHDL examples in any x86 platform:

.. code-block:: bash

   docker run --rm -t \
     -v /$(pwd)://work \
     -w //work \
     ghdl/ext:vunit-master sh -c ' \
       VUNIT_SIMULATOR=ghdl; \
       for f in $(find ./ -name 'run.py'); do python3 $f; done \
     '

where:

* ``run``: create and start a container.
* ``--rm``: automatically remove the container when it exits.
* ``-t``: allocate a pseudo-TTY, to get the stdout of the container forwarded.
* ``-v``: bind mount a volume, to share a folder between the host and the container. In this example the current path in the host is used (``$(pwd)``), and it is bind to `/work` inside the container. Note that both paths must be absolute.
* ``-w``: sets the working directory inside the container, i.e. where the commands we provide as arguments are executed.
* ``ghdl/ext:vunit-master``: the image we want to create a container from.
* ``sh -c``: the command that is executed as soon as the container is created.

Note that:

* The arguments to ``sh -c`` are the same commands that you would execute locally, shall all the dependencies be installed in the host:

   .. code-block:: bash

      VUNIT_SIMULATOR=ghdl
      for f in $(find ./ -name 'run.py'); do python3 $f; done

* The leading slashes in ``/$(pwd)`` and ``//work`` are only required for the paths to be properly handled in MINGW shells, and are ignored in other shells. See `docker/for-win#1509 <https://github.com/docker/for-win/issues/1509>`_.

Final comments:

* All the (automated) flow to generate ``ghdl`` docker images is open source and public, in order to let any user learn and extend it. You can easily replicate it to build you own images with other development dependencies you use.
   * There are ready-to-use images available with additional tools on top of GHDL and VUnit. For example, ``ghdl/ext:vunit-gtkwave`` includes `GTKWave <http://gtkwave.sourceforge.net/>`_.
* Although the licenses of most commercial simulators do not allow to share ready-to-use docker images, it is straightforward to mimic the process.
   * If the installation of a tool needs to be executed with a GUI, a slightly different approach is required. See `Propietary applications inside a docker container <https://github.com/1138-4EB/hwd-ide/wiki/Continuous-Integration-%28CI%29#propietary-applications-inside-a-docker-container>`_
* Both GHDL and VUnit are free software. Docker is almost fully open source, but this depends on the host platform. See `Is Docker still free and open source? <https://opensource.stackexchange.com/questions/5436/is-docker-still-free-and-open-source>`_.

Further info:

* `What is a container <https://www.docker.com/what-container>`_
* `What is docker <https://www.docker.com/what-docker>`_
* `docs.docker.com/engine/reference <https://docs.docker.com/engine/reference>`_
   * `run <https://docs.docker.com/engine/reference/run/>`_
   * `commandline/run <https://docs.docker.com/engine/reference/commandline/run/>`_
* Docker offers two variants Community Edition (CE) and Enterprise Edition (EE). Any of them can be used. Moreover, part of Docker is being split to `Moby project <https://mobyproject.org/>`_.
   * `Announcing Docker Enterprise Edition <https://blog.docker.com/2017/03/docker-enterprise-edition/>`_
   * `Introducing Moby Project: a new open-source project to advance the software containerization movement <https://blog.docker.com/2017/04/introducing-the-moby-project/>`_
* If you don't want or cannot install docker, you can still use it online. `Play with Docker <https://play-with-docker.com>`_ (PWD) *"is a Docker playground which allows users to run Docker commands in a matter of seconds. It gives the experience of having a free Alpine Linux Virtual Machine in browser, where you can build and run Docker containers and even create clusters"*.


.. _json_export:

JSON Export
-----------
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
