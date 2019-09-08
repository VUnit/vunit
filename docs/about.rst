.. _about:

What is VUnit?
==============

VUnit is an open source unit testing framework for VHDL/SystemVerilog
released under the terms of Mozilla Public License, v. 2.0. It
features the functionality needed to realize continuous and automated
testing of your HDL code. VUnit doesn't replace but rather complements
traditional testing methodologies by supporting a "test early and
often" approach through automation.

VUnit reduces the overhead of testing by supporting automatic
discovery of test benches and compilation order as well as including
libraries for common verification tasks. It improves the speed of
development by supporting incremental compilation and by enabling
large test benches to be split up into smaller independent tests. It
increases the quality of projects by enabling large regression suites
to be run on a continuous integration server.

VUnit does not impose any specific verification methodology on its
users. The benefits of VUnit can be enjoyed when writing tests first
or last, when writing long running top level tests or short running
unit tests, when using directed or constrained random testing. Often
projects adopt mix of approaches for different testing needs. VUnit
has been used in production environments where thousands of tests take
several hours to run on powerful multi-core machines as well as in
small open source projects where only a small package is tested in a
few seconds.

Main Features
-------------

-  Python test suite runner that enables powerful test administration,
   can continue testing after fatal run-time errors (e.g. division by
   zero), and ensures test case independence.
-  Automatic scanning of files for tests, file dependencies, and file
   changes enable automatic (re)compilation and execution of test
   suites.
-  Can run test cases in parallel to take advantage of multi-core
   machines.
-  Support for running test benches with multiple generic/parameter settings.
-  :ref:`Scriptable API <python_interface>` as well as :ref:`command line <cli>`
   support.
-  Has ``--gui`` switch to launch test cases in the simulator GUI when debugging is necessary.
-  :doc:`Assertion checker library <./check/user_guide>` that extends VHDL built-in support
   (assert).
-  :doc:`Logging framework <./logging/user_guide>` supporting display and file output, different log
   levels, visibility settings of levels and design hierarchy, output formatting
   and multiple loggers. Supports machine readable output formats that for example can be read by a spreadsheet.
-  Requirements trace-ability through :ref:`JSON Export <json_export>` and :ref:`test attributes <attributes>`.
-  Optional location preprocessor that traces log and check calls back to file
   and line number.
-  Outputs JUnit report files for better `Jenkins`_ :ref:`integration <continuous_integration>`.
-  Builds on the commonly used `xUnit`_ architecture.

Requirements
------------

VUnit depends on a number of components as listed below. Full VUnit
functionality requires Python and a simulator supported by the VUnit
Python test runner. However, VUnit can run with limited functionality
entirely within VHDL using the :doc:`VHDL test runner
<./run/user_guide>`.


Languages
*********

-  VHDL-93
-  VHDL-2002
-  VHDL-2008
-  VHDL-2019
-  Verilog
-  SystemVerilog (Support is experimental)

Operating systems
*****************

-  Windows
-  Linux
-  Mac OS X

Python
******

-  Python 3.4 or higher
-  Python 2.7

   -  VUnit support for Python 2.7 will end in 1 Jan 2020 when it reaches end of life.

Simulators
**********

-  `Aldec Riviera-PRO`_

   -  Tested with Riviera-PRO 2015.06, 2015.10, 2016.02, 2016.10 (x64/x86).
   -  Only VHDL
-  `Aldec Active-HDL`_

   -  Tested with Active-HDL 9.3, 10.1, 10.2, 10.3 (x64/x86)
   -  Only VHDL
-  `Mentor Graphics ModelSim/Questa`_

   -  Tested with 10.1 - 10.5
-  `GHDL`_

   -  Only VHDL
   -  Works with versions >= 0.33
   -  Tested with LLVM and mcode backends, gcc backend might work aswell.
   -  Integrated support for using `GTKWave`_ to view waveforms.
-  `Cadence Incisive`_ (**Experimental**)

   - Community contribution by `Colin Marquardt
     <https://github.com/cmarqu>`_.  VUnit maintainers does not have
     access to this simulator to verify the functionality.
   - Run ``incisive_vhdl_fixup.py`` to remove VHDL constructs that are
      not compatible with Incisive

Getting Started
---------------

There are a number of ways to get started.

-  The :ref:`VUnit User Guide <user_guide>` will guide users on how to use start using
   the basic features of VUnit but also provides information about more
   specific and advanced usage.
-  The :ref:`Run Library User Guide <run_library>` presents the run packages.
-  The :ref:`Check Library User Guide <check_library>` presents the check packages.
-  The :ref:`Logging Library User Guide <logging_library>` presents the log packages.
-  There are also various presentations of VUnit on `YouTube`_. For
   example `an introduction to unit testing (6 min)`_ and a `short
   introduction to VUnit (12 min)`_.

Support
-------

Any bug reports, feature requests or questions about the usage of VUnit
can be made by creating a `new issue`_.

Credits
-------

Founders
********
-  `Lars Asplund <https://github.com/LarsAsplund>`_
-  `Olof Kraigher <https://github.com/kraigher>`_

Notable contributors
********************
- `Colin Marquardt <https://github.com/cmarqu>`_: Cadence Incisive support
- `Sławomir Siluk <https://github.com/slaweksiluk>`_: Verification Components such as Avalon and Wishbone


License
-------

.. |copy|   unicode:: U+000A9 .. COPYRIGHT SIGN

VUnit
*****

VUnit except for OSVVM (see below) is released under the terms of
`Mozilla Public License, v. 2.0`_.

|copy| 2014-2018 Lars Asplund, lars.anders.asplund@gmail.com.

OSVVM
*****

OSVVM is `redistributed`_ with VUnit for your convenience. These
files are licensed under the terms of `ARTISTIC License`_.

|copy| 2010 - 2017 by SynthWorks Design Inc. All rights reserved.

.. _xUnit: http://en.wikipedia.org/wiki/XUnit
.. _Jenkins: http://jenkins-ci.org/
.. _Aldec Riviera-PRO: https://www.aldec.com/en/products/functional_verification/riviera-pro
.. _Aldec Active-HDL: https://www.aldec.com/en/products/fpga_simulation/active-hdl
.. _Mentor Graphics ModelSim/Questa: http://www.mentor.com/products/fv/modelsim/
.. _Cadence Incisive: https://www.cadence.com/content/cadence-www/global/en_US/home/tools/system-design-and-verification/simulation-and-testbench-verification/incisive-enterprise-simulator.html
.. _GHDL: https://github.com/ghdl/ghdl
.. _GTKWave: http://gtkwave.sourceforge.net/
.. _YouTube: https://www.youtube.com/channel/UCCPVCaeWkz6C95aRUTbIwdg
.. _an introduction to unit testing (6 min): https://www.youtube.com/watch?v=PZuBqcxS8t4
.. _short introduction to VUnit (12 min): https://www.youtube.com/watch?v=D8s_VLD91tw
.. _Development document: https://github.com/VUnit/vunit/blob/master/developing.md
.. _new issue: https://github.com/VUnit/vunit/issues/new
.. _Mozilla Public License, v. 2.0: http://mozilla.org/MPL/2.0/
.. _redistributed: https://github.com/VUnit/vunit/blob/master/vunit/vhdl/osvvm
.. _modifications: https://github.com/VUnit/vunit/commit/25fce1b3700e746c3fa23bd7157777dd4f20f0d6
.. _ARTISTIC License: http://www.perlfoundation.org/artistic_license_2_0
