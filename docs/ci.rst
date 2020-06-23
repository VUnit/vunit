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
such as `VirtualBox <https://www.virtualbox.org/>`_, `QEMU <https://www.qemu.org/>`_ or `VMware <https://www.vmware.com>`_. This is still an option, but for most use cases sharing complete system images is overkill. Here, `containerization or operating-system-level virtualization <https://en.wikipedia.org/wiki/Operating-system-level_virtualization>`_ comes into the game. Without going into technical details, containers are a kind of lightweight virtual machines, and the most known product that uses such a technology is `Docker <https://docker.com>`_. Indeed, products such as `Vagrant <https://www.vagrantup.com/>`_ are meant to simplify the usage of virtual machines and/or containers by providing a common (black) box approach. In the end, there are enough open/non-open and free/non-free solutions for each user/company to choose the one that best fits their needs. From the hardware designer point-of-view, we 'just' need a box (no matter the exact underlying technology) that includes VUnit and a simulator.

Fortunately, contributors of project `GHDL <https://github.com/ghdl/ghdl>`_ provide ready-to-use docker images at `hub.docker.com/u/ghdl/dashboard <https://hub.docker.com/u/ghdl/dashboard/>`_. Some of these include not only GHDL but also VUnit. Precisely, ``ghdl/vunit:{mcode|llvm|gcc}`` are images based on Debian Buster image with GHDL built from the latest commit of the master branch, and the latest release of VUnit installed through ``pip``. ``ghdl/vunit:{mcode|llvm|gcc}-master`` images include the latest commit of VUnit from the master branch.

As a result, the burden for the adoption of continuous integration for VUnit users is reduced to using docker; which is available in GNU/Linux, FreeBSD, Windows and macOS, and is supported in most cloud services (`GitHub Actions <https://github.com/features/actions>`_, `Travis CI <https://travis-ci.org/>`_, `AWS <https://aws.amazon.com/docker/>`_, `Codefresh <https://codefresh.io/>`_, etc.) or CI frameworks (`Jenkins <https://jenkins.io/>`_, `Drone <https://drone.io/>`_, `GitLab Runner <https://docs.gitlab.com/runner/>`_, etc.).

For example, script :vunit_file:`examples/vhdl/docker_runall.sh <examples/vhdl/docker_runall.sh>` shows how to run all the VHDL examples in any x86 platform:

.. code-block:: bash

   docker run --rm -t \
     -v /$(pwd)://work \
     -w //work \
     ghdl/vunit:llvm-master sh -c ' \
       VUNIT_SIMULATOR=ghdl; \
       for f in $(find ./ -name 'run.py'); do python3 $f; done \
     '

where:

* ``run``: create and start a container.
* ``--rm``: automatically remove the container when it exits.
* ``-t``: allocate a pseudo-TTY, to get the stdout of the container forwarded.
* ``-v``: bind mount a volume, to share a folder between the host and the container. In this example the current path in the host is used (``$(pwd)``), and it is bind to `/work` inside the container. Note that both paths must be absolute.
* ``-w``: sets the working directory inside the container, i.e. where the commands we provide as arguments are executed.
* ``ghdl/vunit:llvm-master``: the image we want to create a container from.
* ``sh -c``: the command that is executed as soon as the container is created.

Note that:

* The arguments to ``sh -c`` are the same commands that you would execute locally, shall all the dependencies be installed in the host:

   .. code-block:: bash

      VUNIT_SIMULATOR=ghdl
      for f in $(find ./ -name 'run.py'); do python3 $f; done

* The leading slashes in ``/$(pwd)`` and ``//work`` are only required for the paths to be properly handled in MINGW shells, and are ignored in other shells. See `docker/for-win#1509 <https://github.com/docker/for-win/issues/1509>`_.

Final comments:

* All the (automated) flow to generate ``ghdl`` docker images is open source and public, in order to let any user learn and extend it. You can easily replicate it to build you own images with other development dependencies you use.
   * There are ready-to-use images available with additional tools on top of GHDL and VUnit. For example, ``ghdl/ext`` includes `GTKWave <http://gtkwave.sourceforge.net/>`_.
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