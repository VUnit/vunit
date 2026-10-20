.. _hdl_libraries:

HDL Libraries
#############

VHDL
====

Builtins
--------

By default, VUnit provides bare minimal functionality for running testbenches.
In practice, most users want to use HDL utilities to reduce verbosity and improve reporting when writting tests.
VUnit includes several optional libraries in a group named *VHDL builtins* (see :meth:`add_vhdl_builtins() <vunit.ui.VUnit.add_vhdl_builtins>`):

* :vunit_file:`core <vunit/vhdl/core>`
* :vunit_file:`logging <vunit/vhdl/logging>` (see :ref:`logging_library`)
* :vunit_file:`string_ops <vunit/vhdl/string_ops>`
* :vunit_file:`check <vunit/vhdl/check>` (see :ref:`check_library`)
* :vunit_file:`dictionary <vunit/vhdl/dictionary>`
* :vunit_file:`run <vunit/vhdl/run>` (see :ref:`run_library`)
* :vunit_file:`path <vunit/vhdl/path>`

Most of the utilities are based on some internal data types providing dynamic arrays and queues (FIFOs).
See :ref:`data_types_library`.

Communication
-------------

The VUnit communication library (``com``) provides a high-level communication mechanism based on the
`actor model <http://en.wikipedia.org/wiki/Actor_model>`__.

See :meth:`add_com() <vunit.ui.VUnit.add_com>` and :ref:`com_user_guide`.

.. NOTE::
  The Communication Library depends on the builtins, which are added implicitly.

Verification Components
-----------------------

.. note:: This library is released as a *BETA* version. This means non-backwards compatible changes are still likely
  based on feedback from our users.

The VUnit Verification Component Library (VCL) contains a number of useful
:ref:`Verification Components <verification_components>` (VC) as well as a set of utilities for writing your own
verification component.
Verification components allow a better overview in the test bench by raising the abstraction level of bus transactions.
Even if you do not need the advanced features that VCs offer you may still benefit from using peer-verified models of an
AXI-bus instead of re-implementing it yourself.

See :meth:`add_verification_components() <vunit.ui.VUnit.add_verification_components>` and :ref:`vc_user_guide`.

.. NOTE::
  The VCL depends on both the Communication Library and OSVVM, which are added implicitly.

Random
------

VUnit provides random integer vector and pointer generation, based on built-in :ref:`Data Types <data_types_library>`
and OSVVM.

See :meth:`add_random() <vunit.ui.VUnit.add_random>`.

Reflection
----------

These packages use VHDL-2019 reflection to work on values of any type, so no code has to be written or
generated for each type. Add them with :meth:`add_reflection() <vunit.ui.VUnit.add_reflection>`. They
require VHDL-2019 and a simulator with reflection, currently NVC and Riviera-PRO.

Equality Checks for Any Type
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``reflection_check_generic_pkg`` provides ``check_equal`` for any type, with the same parameters as the
``check_equal`` of the :ref:`check library <check_library>`. It is instantiated once for each type, in an
architecture or a package:

.. code-block:: vhdl

    package packet_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => packet_t);
    use packet_checks.all;
    ...
    check_equal(got_packet, expected_packet);
    check_equal(my_checker, got_packet, expected_packet, "After reset");

The check uses the predefined ``"="`` of the type. When it fails, the message names every element that
differs on a row of its own, with its path through nested records and arrays:

.. code-block:: none

    0 ps - check - ERROR - Equality check failed (tb_packet.vhd:21)
                             hdr.addr: got 6, expected 5
                             data(0): got '1', expected '0'

Instances for different types overload on the type. Don't instantiate it for a type that the check
library already covers, such as ``integer`` or ``std_logic_vector``, since the calls become ambiguous.

To share the instances between testbenches, instantiate them in the package that declares the types:

.. code-block:: vhdl

    package types_pkg is
      type packet_t is record
        ...
      end record;

      package packet_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => packet_t);
    end package;

    -- In a testbench
    use work.types_pkg.all;
    use work.types_pkg.packet_checks.all;

Don't instantiate it as a design unit of its own (``package packet_checks is new ...`` at library
level). On Riviera-PRO 2026.04, ``check_equal`` through such an instance silently does nothing. It
neither logs nor counts the check.

The two procedures are also available on their own in ``reflection_check_pkg``, for example to
instantiate them inside a process, where NVC doesn't accept a package instantiation:

.. code-block:: vhdl

    use vunit_lib.reflection_check_pkg.all;
    ...
    process
      procedure check_equal is new check_equal generic map (t => packet_t);
      procedure check_equal is new check_equal_with_checker generic map (t => packet_t);
    begin

OSVVM
-----

VUnit includes the core of `OSVVM <https://github.com/osvvm/>`__ as a submodule and internal dependency of optional
libraries such as Random or Verification Components.
However, it can be added explicitly through :meth:`add_osvvm() <vunit.ui.VUnit.add_osvvm>`.

Moreover, multiple approaches are supported for using `OSVVMLibraries <https://github.com/OSVVM/OsvvmLibraries>`__ in
VUnit.
See :ref:`OSVB: Examples » SISO AXI4 Stream <osvb:Examples:AXI4Stream>`.

System Verilog
==============

Builtins
--------

See :meth:`add_verilog_builtins() <vunit.ui.VUnit.add_verilog_builtins>` and :vunit_file:`vunit_pkg.sv <vunit/verilog/vunit_pkg.sv>`.
