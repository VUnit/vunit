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

.. warning::

    ``to_dict`` and the generic ``push`` are **one-way**. VHDL-2019 reflection can read a value but
    can't create one, and ``'image``/``'value`` aren't allowed on a generic type, so there is no
    ``from_dict`` and no generic ``pop`` that returns the value. To get a record back, pop or get its
    elements one by one with the functions of their types, as a hand-written conversion does.

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
``dict_t``. Any other element type fails on ``record_dict_logger`` with the name of the element.

Pushing Any Type onto a Queue
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. warning::

    The push is **one-way**: there is no ``pop`` that returns the value, for the reasons above.

The generic ``push`` in ``reflection_queue_pkg`` pushes a value of any type onto a
:ref:`queue_t <queue_pkg>`. It pushes the elements one by one, in declaration order and with the
``queue_pkg`` push of their type, and recurses into nested records. The elements are popped with the
``queue_pkg`` pop functions:

.. code-block:: vhdl

    library vunit_lib;
    use vunit_lib.reflection_queue_pkg.all;
    ...
    procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => packet_t);
    ...
    push(queue, packet);
    addr := pop_integer(queue);
    data := pop_std_ulogic_vector(queue);
    state := state_t'value(pop_string(queue));

The element types are the same as for ``to_dict``. Other enumerations are pushed as the name of their
value, which ``'value`` turns back. Any other element type fails on ``reflection_queue_logger`` with the
name of the element. Instantiate it with the selected name ``vunit_lib.reflection_queue_pkg.push``:
Riviera-PRO reports a plain ``is new push`` as ambiguous with the ``queue_pkg`` procedures. Don't
instantiate it for a type that ``queue_pkg`` already covers, such as ``integer``.

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
