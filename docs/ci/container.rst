.. _continuous_integration:container:

Containers and/or Virtual Machines
##################################

The 'classic' approach to virtual machines is through tools such as `VirtualBox <https://www.virtualbox.org/>`_,
`QEMU <https://www.qemu.org/>`_ or `VMware <https://www.vmware.com>`_. However, for most use cases sharing complete system
images is overkill. Here, `containerization or operating-system-level virtualization <https://en.wikipedia.org/wiki/Operating-system-level_virtualization>`_
comes into the game. Without going into technical details, containers are a kind of lightweight virtual machines, and the
most known product that uses the technology is `Docker <https://docker.com>`_.

.. HINT:: Products such as `Vagrant <https://www.vagrantup.com/>`_ are meant to simplify the usage of virtual machines and/or
   containers by providing a common (black) box approach. In the end, there are enough open/non-open and free/non-free
   solutions for each user/company to choose the one that best fits their needs. From the hardware designer point-of-view,
   we 'just' need a box (no matter the exact underlying technology) that includes VUnit and a simulator.

Contributors of project `GHDL <https://github.com/ghdl/ghdl>`_ provide ready-to-use docker images at `hub.docker.com/u/ghdl/dashboard <https://hub.docker.com/u/ghdl/dashboard/>`_.
Some of these include not only GHDL but also VUnit. Precisely, ``ghdl/vunit:{mcode|llvm|gcc}`` are images based on Debian
Buster image, with GHDL built from the latest commit of the master branch, and the latest release of VUnit installed through
``pip``. ``ghdl/vunit:{mcode|llvm|gcc}-master`` images include the latest commit of VUnit from the master branch. There are
other ready-to-use images with additional tools. For example, ``ghdl/ext`` includes `GTKWave <http://gtkwave.sourceforge.net/>`_.

As a result, the burden for the adoption of continuous integration for VUnit users is significantly reduced by using
containers; which are available in GNU/Linux, FreeBSD, Windows and macOS, and are supported on most cloud services
(`GitHub Actions <https://github.com/features/actions>`_, `Travis CI <https://travis-ci.org/>`_,
`AWS <https://aws.amazon.com/docker/>`_, `Codefresh <https://codefresh.io/>`_, etc.) or CI frameworks
(`Jenkins <https://jenkins.io/>`_, `Drone <https://drone.io/>`_, `GitLab Runner <https://docs.gitlab.com/runner/>`_, etc.).

For example, script :vunit_file:`examples/vhdl/docker_runall.sh <examples/vhdl/docker_runall.sh>` shows how to run all the
:ref:`VHDL examples <examples>` on any x86 platform:

.. code-block:: bash

   docker run --rm \
     -v /$(pwd)://work \
     -w //work \
     ghdl/vunit:llvm-master sh -c ' \
       VUNIT_SIMULATOR=ghdl; \
       for f in $(find ./ -name 'run.py'); do python3 $f; done \
     '

where:

* ``run``: create and start a container.
* ``--rm``: automatically remove the container when it exits.
* ``-v``: bind mount a volume, to share a folder between the host and the container. In this example the current path in the
  host is used (``$(pwd)``), and it is bind to `/work` inside the container. Note that both paths must be absolute.
* ``-w``: sets the working directory inside the container, i.e. where the commands we provide as arguments are executed.
* ``ghdl/vunit:llvm-master``: the image we want to create a container from.
* ``sh -c``: the command that is executed as soon as the container is created.

Note that, the arguments to ``sh -c`` are the same commands that you would execute locally, shall all the dependencies be
installed on the host:

.. code-block:: bash

   VUNIT_SIMULATOR=ghdl
   for f in $(find ./ -name 'run.py'); do python3 $f; done

.. HINT:: The leading slashes in ``/$(pwd)`` and ``//work`` are only required for the paths to be properly handled in MINGW64
   shells, and are ignored in other shells. See `docker/for-win#1509 <https://github.com/docker/for-win/issues/1509>`_.

.. NOTE:: Docker offers two variants Community Edition (CE) and Enterprise Edition (EE). Any of them can be used. Moreover,
   part of Docker is being split to `Moby project <https://mobyproject.org/>`_.

   * `Announcing Docker Enterprise Edition <https://blog.docker.com/2017/03/docker-enterprise-edition/>`_
   * `Introducing Moby Project: a new open-source project to advance the software containerization movement <https://blog.docker.com/2017/04/introducing-the-moby-project/>`_

.. HINT:: If you don't want or cannot install docker, you can still use it online. `Play with Docker <https://play-with-docker.com>`_
   (PWD) *"is a Docker playground which allows users to run Docker commands in a matter of seconds. It provides a free Alpine
   Linux Virtual Machine in browser, where you can build and run Docker containers and even create clusters"*.

.. NOTE:: Both GHDL and VUnit are free software. Docker is almost fully open source, but it depends on the host platform.
   See `Is Docker still free and open source? <https://opensource.stackexchange.com/questions/5436/is-docker-still-free-and-open-source>`_.

.. NOTE::

   * `What is a container <https://www.docker.com/what-container>`_
   * `What is docker <https://www.docker.com/what-docker>`_
   * `docs.docker.com/engine/reference <https://docs.docker.com/engine/reference>`_
      * `run <https://docs.docker.com/engine/reference/run/>`_
      * `commandline/run <https://docs.docker.com/engine/reference/commandline/run/>`_

.. _continuous_integration:container:customizing:

Customizing existing images
***************************

All the (automated) flow to generate images in `ghdl/docker <https://github.com/ghdl/docker>`_ is open source and public.
Hence, any user can learn and extend it. However, many users will want to just add a few dependencies to an existing image,
without the hassle of handling credentials to access `hub.docker.com <https://hub.docker.com/>`_. That can be achieved with
a short ``Dockerfile``. For instance:

.. code-block:: Dockerfile

   FROM ghdl/vunit:llvm-master

   RUN pip install pytest matplotlib

Then, in the CI workflow:

.. code-block:: bash

   docker build -t imageName - < path/to/Dockerfile
   docker run ... imageName ...

Packaging non-FLOSS simulators
******************************

Although the licenses of most commercial simulators do not allow to share ready-to-use docker images, it is straightforward
to mimic the process for in-house usage. Unlike GHDL, many commercial simulators provide a GUI and/or require a GUI for executing
the installer. In those contexts, `mviereck/x11docker <https://github.com/mviereck/x11docker>`_ and
`mviereck/runx <https://github.com/mviereck/runx>`_ can be useful.
See `mviereck/x11docker#201 <https://github.com/mviereck/x11docker/issues/201>`_.

