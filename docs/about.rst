.. _about:

What is VUnit?
==============

VUnit is an open source unit testing framework for VHDL/SystemVerilog
released under the terms of `Mozilla Public License, v. 2.0`_. It
features the functionality needed to realize continuous and automated
testing of your HDL code. VUnit doesn't replace but rather complements
traditional testing methodologies by supporting a *"test early and
often"* approach through automation.

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

Getting Started
---------------

There are a number of ways to get started.

-  :ref:`VUnit User Guide <user_guide>` will guide users on how to use start using
   the basic features of VUnit but also provides information about more
   specific and advanced usage.
-  :ref:`Run Library User Guide <run_library>` presents the run packages.
-  :ref:`Check Library User Guide <check_library>` presents the check packages.
-  :ref:`Logging Library User Guide <logging_library>` presents the log packages.
-  There are also various presentations of VUnit on `YouTube`_. For
   example `an introduction to unit testing (6 min)`_ and a `short
   introduction to VUnit (12 min)`_.

Support
-------

Any bug reports, feature requests or questions about the usage of VUnit
can be made by creating a `new issue`_.

Credits and License
-------------------

-  Founders:

  -  `Lars Asplund <https://github.com/LarsAsplund>`_

  -  `Olof Kraigher <https://github.com/kraigher>`_

-  Notable contributors:

  -  `Colin Marquardt <https://github.com/cmarqu>`_:

    -  Cadence Incisive support

  -  `Sławomir Siluk <https://github.com/slaweksiluk>`_:

    -  Verification Components (such as Avalon and Wishbone)

  -  `Unai Martinez-Corral <https://github.com/umarcor>`_:

    -  Co-simulation with GHDL's VHPIDIRECT interface (`VUnit/cosim <https://github.com/VUnit/cosim>`_, based on `ghdl/ghdl-cosim <https://github.com/ghdl/ghdl-cosim>`_)

    -  Continuous Integration (CI)

.. include:: license.rst

.. _xUnit: http://en.wikipedia.org/wiki/XUnit
.. _Jenkins: http://jenkins-ci.org/
.. _YouTube: https://www.youtube.com/channel/UCCPVCaeWkz6C95aRUTbIwdg
.. _an introduction to unit testing (6 min): https://www.youtube.com/watch?v=PZuBqcxS8t4
.. _short introduction to VUnit (12 min): https://www.youtube.com/watch?v=D8s_VLD91tw
.. _new issue: https://github.com/VUnit/vunit/issues/new
