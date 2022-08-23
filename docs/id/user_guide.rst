.. _id_user_guide:

################
Identity Package
################

************
Introduction
************

The VUnit identity package (``id_pkg``) provides a way of creating a hierarchical
structure of named objects in a testbench. It enhances the capabilities provided by VHDL's
``simple_name``, ``instance_path_name`` and ``path_name`` attributes and removes some
limitations of name attributes and string-based names in general.

***********************************************
Limitations of Name Strings and Name Attributes
***********************************************

When giving names to a testbench object, for example a verification component (VC), we can use
one of the VHDL name attributes. In the example below we have a testbench with two
VCs, each with a name generic. Each VC verifies an interface on the device under test (DUT)
and when it reaches full test coverage it produces a log message containing its name
and a confirmation of the successful verification.

We use the ``path_name`` attribute of the VC entity instantiation label to give
``name`` a value but it should be noted that at the time of writing not all simulators support
using ``path_name`` of the instantiation itself when defining the instantiation.

.. code-block:: vhdl

   architecture testbench of tb_dut is
   begin
     stimuli: process
      ...

     my_dut : entity work.dut
       port map(
         ...
       );

     interface_1_checker : entity work.verification_component_1
       generic map(
         name => interface_1_checker'path_name
       );
       port map(
         ...
       );

     interface_2_checker : entity work.verification_component_2
       generic map(
         name => interface_2_checker'path_name
       );
       port map(
         ...
       );
   end architecture;

A log message might look like this:

.. code-block:: Bash

   Full test coverage reached for :tb_dut:interface_1_checker:. No errors found.

The name produced by the ``path_name`` attribute, ``:tb_dut:interface_1_checker:``,
reflects the logical structure of the testbench and gives a clear indication of who is the
producer. However, ``path_name`` knows nothing about logical structure, it only knows about
code structure and that is not necessarily the same. Imagine we want to clean-up our
testbench by moving some of the declarations in the architecture declarative part to a
place more local to where they are used. We can do this by adding a block statement,
for example

.. code-block:: vhdl

   local_declarations : block is
     -- Local declarations of signals, constants etc
   begin
     interface_1_checker : entity work.verification_component_1
       generic map(
         name => interface_1_checker'path_name
       );
       port map(
         ...
       );

     interface_2_checker : entity work.verification_component_2
       generic map(
         name => interface_2_checker'path_name
       );
       port map(
         ...
       );
     end block;

By doing this we change the code structure and the naming along with that.

.. code-block:: console

   Full test coverage reached for :tb_dut:local_declarations:interface_1_checker:. No errors found.

In order to avoid breaking the logical structure we need to avoid the name attributes and
use explicit strings instead:

.. code-block:: vhdl

   interface_1_checker : entity work.verification_component_1
    generic map(
      name => ":tb_dut:interface_1_checker:"
    );
    port map(
      ...
    );

Another beniefit of not using the name attributes is that the name is no longer limited
by the rules of identifier naming. We can call the VC ``:tb_dut:1st interface checker:``
should we want to.

Regardless if we use a name attribute or provide the name explicitly, the notion of
hierarchy is determined by a naming convention and not by the ``string`` type itself.
This creates an uncertainty for the VC designer. Can they be sure that a ``name``
containing colons is an expression of hierarchy? If not, the VC cannot build any
functionality that is based on traversing the name hierarchy.

Even if that convention is followed there are limitations to what we can do since only
the ancestry is included in the name string and we cannot use it to traverse the full name
space.

****************
Using Identities
****************

To overcome the problems outlined in the previous section ``id_pkg`` provides an ``id_t``
type. ``id_t`` is compatible with VHDL name attributes in the sense that we can create
an identity from a name attribute.

.. code-block:: vhdl

   vc_1_id := get_id(interface_1_checker'path_name);

or from a string if our logical structure doesn't match the code structure

.. code-block:: vhdl

   vc_1_id := get_id(":tb_dut:interface_1_checker:");

We can also omit the leading and trailing colons for simplicity

.. code-block:: vhdl

   vc_1_id := get_id("tb_dut:interface_1_checker");

The identity returned when calling ``get_id`` represents the last component. Calling ``name(vc_1_id)``
will return the string ``"interface_1_checker"`` and calling ``full_name(vc_1_id)`` returns
``"tb_dut:interface_1_checker"``. However, all identities are created and we can get the parent
(``tb_dut``) identity by calling the ``get_parent`` function:

.. code-block:: vhdl

   parent_id := get_parent(vc_id);

Calling ``get_id`` only creates the identities missing in the tree of identities formed by previous calls
to the function. For example, calling ``get_id`` with the path for ``interface_2_checker`` will not create
a new identity for ``tb_dut`` since that part of the ``interface_2_checker`` path already exists:

.. code-block:: vhdl

   vc_2_id := get_id("tb_dut:interface_2_checker");

Another way to add identities is to use ``get_child`` with a parent id parameter.
The following is an equivalent way of creating the identity for ``interface_2_checker``:

.. code-block:: vhdl

   vc_2_id := get_id("interface_2_checker", parent => parent_id);

To visualize what has been created by previous ``get_id`` calls we can use ``get_tree`` to see the subtree of
identities rooted in a given identity. For example,

.. code-block:: vhdl

  report "This is the tb_dut subtree:" & get_tree(parent_id);

will output:

.. code-block:: bash

  This is the tb_dut subtree:
  tb_dut
  +---interface_1_checker
  \---interface_2_checker

The string returned by ``get_tree`` starts with a linefeed character (LF) to make sure that root line of the
tree is aligned with the rest. We can omit this intial LF character by setting the optional parameter
``initial_lf`` false.

We can also call ``get_tree`` without any parameters to see the full identity tree. This is a good way
of getting an overview of all identities created in user code, by third party IPs, and in VUnit itself.
The output of such a call is exemplified below:

.. code-block:: bash

  (root)
  +---default
  +---vunit_lib
  |   \---dictionary
  +---check
  +---runner
  \---tb_dut
      +---interface_1_checker
      \---interface_2_checker

At the root of the tree is a symbol ``(root)`` which represents the predefined ``root_id``. ``root_id`` has no name
but is given a symbol in the tree representation for clarity. The lack of name means that we cannot create a new
identity with no name as that is already taken.

In general we can determine if an identity is taken by calling ``exists`` with the full name of the identity
or a partial name relative to a parent identity. For example, calling ``exists("")`` would always return ``true``.
In this case ``exists("tb_dut:interface_1_checker")`` and ``exists("interface_1_checker", parent => get_id("tb_dut")``
would also return ``true`` but ``exists("interface_1_checker")`` would return ``false``.

The ``get_tree`` function works by traversing the entire identity tree to collect the name of each identity.
We can write our own functionality based on traversing the tree by using the ``get_parent`` function described
earlier and the ``num_children`` and ``get_child`` functions. ``num_children`` returns the number of children
identities a given identity has. For example, ``num_children(get_id("tb_dut"))`` returns 2.
Each of the children identities can then be retrieved by calling ``get_child`` with an index in the range
[0, number of children - 1]. For example, ``get_child(get_id("tb_dut"), 1)`` will return the identity for
``interface_2_checker``.

******************
Sharing Identities
******************

All identifers have a primary owner but the same identity can also be used by others acting on behalf
of the primary owner. In the previous examples we had a VC being the primary owner of the identity
named ``tb_dut:interface_1_checker``. That VC can have a :ref:`logger <logging_library>` and an
:ref:`actor <com_user_guide>` to provide logging and communication services. These two objects would
be created from the ``tb_dut:interface_1_checker`` identity and act on behalf of the associated VC.









