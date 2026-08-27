.. _continuous_integration:manual:

Manual setup
############

Since CI/CD services typically provide full-featured Ubuntu/Debian, Windows and/or macOS environments, regular installation
procedures can be used (see :ref:`installing`). That is, an HDL simulator and Python need to be installed by any means.

.. IMPORTANT:: When installing the development version of VUnit, remember to install the dependencies (see :vunit_file:`requirements.txt`).

Due to the single supported open source simulator being GHDL, most users on GitHub are likely to install it along with VUnit.
There are six possible procedures to setup GHDL:

* `ghdl.rtfd.io: Releases and sources <https://ghdl.readthedocs.io/en/latest/getting/Releases.html>`_:

   * Use a package manager, such as ``apt`` or ``pacman``.

   * Get and extract a tarball/zipfile from the *latest stable* release: `github.com/ghdl/ghdl/releases/latest <https://github.com/ghdl/ghdl/releases/latest>`_.

   * Get and extract a tarball/zipfile from the *nightly* pre-release: `github.com/ghdl/ghdl/releases/nightly <https://github.com/ghdl/ghdl/releases/nightly>`_.

      * (On GitHub Actions only) Use Action `ghdl/setup-ghdl <https://github.com/ghdl/setup-ghdl>`_.

* Use one of the Docker/OCI images provided in `ghdl/docker <https://github.com/ghdl/docker>`_.

* Build it from sources: `ghdl.rtfd.io: Building GHDL from Sources <https://ghdl.readthedocs.io/en/latest/getting/index.html>`_.

.. HINT:: Since building GHDL each time is time-consuming, it is recommented to use pre-built tarballs/zipfiles or Docker/OCI
   images. Images/containers usually provide the fastest startup time, because all the dependencies can be pre-installed already.
