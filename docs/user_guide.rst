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

.. _special_generics:

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

:vunit_example:`VHDL User Guide Example <vhdl/user_guide>`
  The most minimal VUnit VHDL project covering the basics of this user
  guide.

:vunit_example:`SystemVerilog User Guide Example <verilog/user_guide>`
  The most minimal VUnit SystemVerilog project covering the basics of
  this user guide.

:vunit_example:`VHDL UART Example <vhdl/uart>`
  A more realistic test bench of an UART to show VUnit VHDL usage on a
  typical module.

:vunit_example:`SystemVerilog UART Example <verilog/uart>`
  A more realistic test bench of an UART to show VUnit SystemVerilog
  usage on a typical module.

:vunit_example:`Run Example <vhdl/run>`
  Demonstrates the VUnit run library.

:vunit_example:`Check Example <vhdl/check>`
  Demonstrates the VUnit check library.

:vunit_example:`Logging Example <vhdl/logging>`
  Demonstrates VUnit's support for logging.

:vunit_example:`Array Example <vhdl/array>`
  Demonstrates the ``array_t`` data type of ``array_pkg.vhd`` which
  can be used to handle dynamically sized 1D, 2D and 3D data as well
  as storing and loading it from csv and raw files.

:vunit_example:`Array and AXI4 Stream Verification Components Example <vhdl/array_axis_vcs>`
  Demonstrates ``array_t``, ``axi_stream_master_t`` and ``axi_stream_slave_t``
  data types of ``array_pkg.vhd``, ``stream_master_pkg`` and ``stream_slave_pkg``,
  respectively. Also, ``push_axi_stream`` of ``axi_stream_pkg`` is used. A CSV file
  is read, the content is sent in a row-major order to an AXI Stream buffer (FIFO)
  and it is received back to be saved in a different file. Further information can
  be found in the :ref:`verification component library user guide <vc_library>`,
  in subsection :ref:`Stream <stream_vci>` and in
  :vunit_file:`vhdl/verification_components/test/tb_axi_stream.vhd <vunit/vhdl/verification_components/test/tb_axi_stream.vhd>`.

:vunit_example:`Generating tests <vhdl/generate_tests>`
  Demonstrates generating multiple test runs of the same test bench
  with different generic values. Also demonstrates use of ``output_path`` generic
  to create test bench output files in location specified by VUnit python runner.

:vunit_example:`Vivado IP example <vhdl/vivado>`
  Demonstrates compiling and performing behavioral simulation of
  Vivado IPs with VUnit.

:vunit_example:`Communication library example <vhdl/com>`
  Demonstrates the ``com`` message passing package which can be used
  to communicate arbitrary objects between processes.  Further reading
  can be found in the :ref:`com user guide <com_user_guide>`

Continuous Integration (CI)
---------------------------

Because VUnit features the functionality needed to realize continuous and automated testing of HDL code, it is a very valuable resource in continuous integration environments. Indeed, it has :ref:`built-in <cli>` support for `Xunit <https://en.wikipedia.org/wiki/List_of_unit_testing_frameworks>`_ test report generation, which allows dynamic interpretation of results avoiding custom (and error-prone) parsing of the logs. Furthermore, VUnit can be easily executed in many different platforms (either operating systems or architectures), because it is written in Python, which is an interpreted language.

However, besides the sources and VUnit, a `HDL compiler/simulator <https://en.wikipedia.org/wiki/List_of_HDL_simulators>`_ is required in order to run the tests. Due to performance, all the HDL simulators are written in compiled languages, which makes the releases platform specific. I.e., each simulator needs to be specifically compiled for a given architecture and operating system. This might represent a burden for the adoption of continuous integration in hardware development teams, as it falls into the category of dev ops.

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
