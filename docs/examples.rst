.. _examples:

Examples
========

.. HINT::
  Most of the examples expect the simulator to support several VHDL 2008 features.
  This is made explicit by using ``context`` instead of multiple ``use`` statements.
  However, some vendors do support enough VHDL 2008 features in order to run some of the examples, but they cannot
  handle contexts.
  In those cases, replacing ``context vunit_lib.vunit_context`` with the content of :vunit_file:`vunit/vhdl/vunit_context.vhd`
  and :vunit_file:`vunit/vhdl/data_types/src/data_types_context.vhd` might work.

.. include:: examples.inc
