.. _about:

What is VUnit?
==============

VUnit is an open source unit testing framework for VHDL/SystemVerilog
released under the terms of Mozilla Public License, v. 2.0. It
features the functionality needed to realize continuous and automated
testing of your HDL code. VUnit doesn't replace but rather complements
traditional testing methodologies by supporting a "test early and
often" approach through automation.

**NOTE:** SystemVerilog support is experimental.

Project Mission
---------------

The VUnit project mission is to apply best SW testing practices to the
world of HDLs by providing the tools missing to adapt to such
practices. The major missing piece is the unit testing framework,
hence the name V(HDL)Unit. However, VUnit also provides supporting
functionality not normally considered as a part of a unit testing
framework.

Main Features
-------------

-  Builds on the commonly used `xUnit`_ architecture.
-  Python test runner that enables powerful test administration, can
   handle fatal run-time errors (e.g. division by zero), and
   ensures test case independence.
-  Scanners for identifying files, tests, file dependencies, and file
   changes enable automatic (re)compilation and execution of test
   suites.
-  Can run test cases in parallel to take advantage of multi-core
   machines.
-  :ref:`Scriptable API <python_interface>` as well as :ref:`command line <cli>`
   support.
-  Support for running same test suite with different generics.
-  :doc:`VHDL test runner <./run/user_guide>` which enables test execution for not fully supported
   simulators.
-  :doc:`Assertion checker library <./check/user_guide>` that extends VHDL built-in support
   (assert).
-  :doc:`Logging framework <./logging/user_guide>` supporting display and file output, different log
   levels, filtering on level and design hierarchy, output formatting
   and multiple loggers. Spreadsheet tool integration.
-  Location preprocessor that traces log and check calls back to file
   and line number.
-  JUnit report files for better `Jenkins`_ :ref:`integration
   <continuous_integration>`.

Requirements
------------

VUnit depends on a number of components as listed below. Full VUnit
functionality requires Python and a simulator supported by the VUnit
Python test runner. However, VUnit can run with limited functionality
entirely within VHDL which means that unsupported simulators can be used
as well. Prototype work has been done to fully support other simulators
but this work is yet to be completed and released.

Languages
*********

-  VHDL-93
-  VHDL-2002
-  VHDL-2008
-  Verilog
-  SystemVerilog

Operating systems
*****************

-  Windows
-  Linux
-  Mac OS X

Python
******

-  Python 2.7
-  Python 3.3 or higher

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

   -  Community contribution. VUnit maintainers does not have access to this simulator to verify the functionality.
   -  Run ``incisive_vhdl_fixup.py`` to remove VHDL constructs that are not compatible with Incisive

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

Main Contributors
-----------------

-  Lars Asplund
-  Olof Kraigher

License
-------

.. |copy|   unicode:: U+000A9 .. COPYRIGHT SIGN

VUnit
*****

VUnit except for OSVVM (see below) is released under the terms of
`Mozilla Public License, v. 2.0`_.

|copy| 2014-2017 Lars Asplund, lars.anders.asplund@gmail.com.

OSVVM
*****

OSVVM is `redistributed`_ with VUnit for your convenience. Derivative work
is located under `examples/vhdl/osvvm\_integration/src`_. These
files are licensed under the terms of `ARTISTIC License`_.

|copy| 2010 - 2017 by SynthWorks Design Inc. All rights reserved.

.. _xUnit: http://en.wikipedia.org/wiki/XUnit
.. _Jenkins: http://jenkins-ci.org/
.. _Aldec Riviera-PRO: https://www.aldec.com/en/products/functional_verification/riviera-pro
.. _Aldec Active-HDL: https://www.aldec.com/en/products/fpga_simulation/active-hdl
.. _Mentor Graphics ModelSim/Questa: http://www.mentor.com/products/fv/modelsim/
.. _Cadence Incisive: https://www.cadence.com/content/cadence-www/global/en_US/home/tools/system-design-and-verification/simulation-and-testbench-verification/incisive-enterprise-simulator.html
.. _GHDL: https://sourceforge.net/projects/ghdl-updates/
.. _GTKWave: http://gtkwave.sourceforge.net/
.. _YouTube: https://www.youtube.com/channel/UCCPVCaeWkz6C95aRUTbIwdg
.. _an introduction to unit testing (6 min): https://www.youtube.com/watch?v=PZuBqcxS8t4
.. _short introduction to VUnit (12 min): https://www.youtube.com/watch?v=D8s_VLD91tw
.. _Development document: https://github.com/VUnit/vunit/blob/master/developing.md
.. _new issue: https://github.com/VUnit/vunit/issues/new
.. _Mozilla Public License, v. 2.0: http://mozilla.org/MPL/2.0/
.. _redistributed: https://github.com/VUnit/vunit/blob/master/vunit/vhdl/osvvm
.. _modifications: https://github.com/VUnit/vunit/commit/25fce1b3700e746c3fa23bd7157777dd4f20f0d6
.. _examples/vhdl/osvvm\_integration/src: https://github.com/VUnit/vunit/blob/master/examples/vhdl/osvvm_integration/src
.. _ARTISTIC License: http://www.perlfoundation.org/artistic_license_2_0
