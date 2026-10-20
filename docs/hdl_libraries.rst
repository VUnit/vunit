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

Record Dictionaries
~~~~~~~~~~~~~~~~~~~

``record_dict_pkg`` converts a value of any record type to a :ref:`dict_t <data_types_library>` with
VHDL-2019 reflection, so no conversion function has to be written or generated for each record type. A
``dict_t`` can be printed, compared, queued or passed to code that takes key-value data, such as the
``dict_t`` arguments of the VUnit Python bridge.

``to_dict`` is a generic function, instantiated once for each record type and then called with the record:

.. code-block:: vhdl

    library vunit_lib;
    use vunit_lib.record_dict_pkg.all;
    ...
    function to_dict is new to_dict generic map (record_t => packet_t);
    ...
    dict := to_dict(packet);
    check_equal(get_integer(dict, "addr"), 5);

Instances for different record types can share the name ``to_dict``. The instantiation is needed since
VHDL has no implicit instantiation of generic subprograms, and a function can't take ``packet'reflect``
directly: a mirror is an access type, which a parameter can only take as a variable. ``to_dict``
reflects its own parameter instead.

Element names become lower case keys. ``integer``, ``real``, ``boolean``, ``bit``, ``std_ulogic``,
``character``, ``time``, ``string``, ``std_ulogic_vector``, ``unsigned`` and ``signed`` elements keep their
type, other enumerations are stored as the name of their value, and a nested record becomes a nested
``dict_t``. Any other element type fails on ``record_dict_logger`` with the name of the element. The
conversion is one-way, since reflection cannot create a record value.

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
