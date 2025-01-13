.. _installing:

Installing
##########


Requirements
============

.. NOTE::
  Full VUnit functionality requires Python (3.8 or higher) and a simulator
  supported by the VUnit Python test runner (see list below).
  However, VUnit can run with limited functionality entirely within VHDL using
  the :doc:`VHDL test runner <./run/user_guide>`.

Language
--------

VUnit supports VHDL (93, 2002, 2008 and 2019),
Verilog and (experimentally) SystemVerilog.

Platform
--------

VUnit is known to work on GNU/Linux, Windows and Mac OS; on x86, x64, armv7 and aarch64.

Simulator
----------

VHDL only
^^^^^^^^^

*  `Aldec Riviera-PRO`_: Tested with Riviera-PRO 2015.06, 2015.10, 2016.02, 2016.10 (x64/x86).

*  `Aldec Active-HDL`_: Tested with Active-HDL 9.3, 10.1, 10.2, 10.3 (x64/x86).

*  `GHDL`_

  *  Tested with LLVM and mcode backends; GCC backend might work aswell.

  *  Works with versions >= 0.33.

     .. HINT::

       GHDL is a rolling project, it is therefore recommended to use the latest
       `nightly release <https://github.com/ghdl/ghdl/releases/tag/nightly>`_ tarball.

*  `NVC`_: Works with versions >= 1.9.

.. HINT::
  GHDL and NVC support using `GTKWave`_ to view waveforms.

.. _Aldec Riviera-PRO: https://www.aldec.com/en/products/functional_verification/riviera-pro
.. _Aldec Active-HDL: https://www.aldec.com/en/products/fpga_simulation/active-hdl
.. _GHDL: https://github.com/ghdl/ghdl
.. _nightly release: https://github.com/ghdl/ghdl/releases/tag/nightly
.. _GTKWave: http://gtkwave.sourceforge.net/
.. _NVC: https://www.nickg.me.uk/nvc/

VHDL or SystemVerilog
^^^^^^^^^^^^^^^^^^^^^

*  `Mentor Graphics ModelSim/Questa`_: Tested with 10.1 - 10.5

.. CAUTION::

  *  `Cadence Incisive`_ (**Experimental**)

    * Community contribution by `Colin Marquardt <https://github.com/cmarqu>`_.
      VUnit maintainers do not have access to this simulator to verify the functionality.

    * Run ``incisive_vhdl_fixup.py`` to remove VHDL constructs that are not
      compatible with Incisive.

.. _Mentor Graphics ModelSim/Questa: http://www.mentor.com/products/fv/modelsim/
.. _Cadence Incisive: https://www.cadence.com/content/cadence-www/global/en_US/home/tools/system-design-and-verification/simulation-and-testbench-verification/incisive-enterprise-simulator.html

.. _installing_pypi:

Using the Python Package Manager
================================

The recommended way to get VUnit is to install the :ref:`latest stable release <release:latest>` via `pip <https://pip.pypa.io/en/stable/>`__:

.. code-block:: console

   > pip install vunit_hdl

Once installed, VUnit may be updated to new versions via a similar method:

.. code-block:: console

   > pip install -U vunit_hdl

Occasionally, pre-releases and development versions are available via `pip <https://pip.pypa.io/en/stable/>`__.
These give early access to updates before the next planned release has been fully completed. These are installed
by adding the ``--pre`` option to the ``pip install`` command.

.. _installing_master:

Using the Development Version
=============================

Start by cloning our `GIT repository on GitHub <https://github.com/vunit/vunit/>`__:

.. code-block:: console

   git clone --recurse-submodules https://github.com/VUnit/vunit.git

The ``--recurse-submodules`` option initializes `OSVVM <https://github.com/JimLewis/OSVVM>`__ which is included as a submodule in the VUnit repository.

To be able to import :class:`VUnit <vunit.ui.VUnit>` in your ``run.py`` script
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
   the VUnit repository root directory. Note that you shouldn't point
   to the vunit directory within the root directory.

3. Add the following to your ``run.py`` file **before** the ``import vunit``
   statement:

.. code-block:: python

   import sys
   sys.path.append("/path/to/vunit_repo_root/")
   import vunit

.. _installing_dev:

For VUnit Developers
====================

For those interested in development of VUnit, it is best to install
VUnit so that the sources from git are installed in-place instead of
to the Python site-packages directory. This can be achieved by using
the ``-e`` flag with ``pip``, or the ``develop`` option with
``setup.py``, or setting the ``PYTHONPATH`` environment variable.

.. code-block:: console

   > git clone https://github.com/VUnit/vunit.git
   > cd vunit

   > python setup.py develop
   or
   > pip install -e .

By installing VUnit in this manner, the git sources can be edited directly in
your workspace while the ``VUnit`` package is still globally available in your
Python environment.
