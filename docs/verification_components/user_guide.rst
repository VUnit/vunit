.. _vc_user_guide:

Verification Components User Guide
==================================

.. NOTE::
  This library is released as a *BETA* version.
  This means non-backwards compatible changes are still likely based on feedback from our users.

Included verification components (VCs):

- Avalon Memory-Mapped master
- Avalon Memory-Mapped slave
- Avalon Streaming sink
- Avalon Streaming source
- AXI-Lite master
- AXI read slave
- AXI write slave
- AXI stream master
- AXI stream monitor
- AXI stream protocol checker
- AXI stream slave
- RAM master
- Wishbone master
- Wishbone slave
- UART master
- UART slave

In addition to VCs VUnit also has the concept of :ref:`Verification Component Interfaces <verification_component_interfaces>` (VCI).
A single VC typically implements several VCIs.
For example an AXI-lite VC or RAM master VC can support the same generic bus master and synchronization VCI while also
supporting their own bus specific VCIs.

.. TIP::
  The main benefit of generic VCIs is to reduce redundancy between VCs and allow the user to write generic code that
  will work regardless of the specific VC instance used.
  For example control registers might be defined as a RAM-style bus in a submodule but be mapped to an AXI-lite
  interface on the top level.
  The same testbench code for talking to the submodule can be used in both the submodule test bench as well as the top
  level test bench regardless of the fact that two different VCs have been used.
  Without generic VCIs copy pasting the code and changing the type of read/write procedure call would be required.

Neither a VC or a VCI there is the :ref:`memory model <memory_model>` which is a model of a memory space such as the
DRAM address space in a computer system.
The memory mapped slave VCs such as AXI and Wishbone make transactions against the memory model which provides access
permissions, expected data settings as well as the actual buffer for reading and writing data.

.. toctree::
   :maxdepth: 1
   :hidden:

   memory_model

.. _verification_component_interfaces:

Verification Component Interfaces
---------------------------------

A verification component interface (VCI) is a procedural interface to a VC.
A VCI is defined as procedures in a package file.
Several VCs can support the same generic VCI to enable code re-use both for the users and the VC-developers.

List of VCIs included in the main repository:

Included verification component interfaces (VCIs):

* :ref:`Bus master <bus_master_vci>`: generic read and write of bus with address and byte enable.
* :ref:`Stream <stream_vci>`: push and pop of data stream without address.
* :ref:`Synchronization <sync_vci>`: wait for time and events.

.. toctree::
   :maxdepth: 1
   :hidden:

   vci

.. _verification_components:

Verification Components
-----------------------

A verification component (VC) is an entity that is normally connected to the DUT via a bus signal interface such as
AXI-Lite.
The main test sequence in the test bench sends messages to the VCs that will then perform the actual bus signal
transactions.
The benefit of this is both to raise the abstraction level of the test bench as well as making it easy to have parallel
activity on several bus interfaces.

A VC typically has an associated package defining procedures for sending to and receiving messages from the VC.
Each VC instance is associated with a handle that is created in the test bench and set as a generic on the VC
instantiation.
The handle is given as an argument to the procedure calls to direct messages to the specific VC instance.


VC and VCI Compliance Testing
=============================

VUnit establishes a standard for VCs and VCIs, designed around a set of rules that promote flexibility,
reusability, interoperability, and future-proofing of VCs and VCIs.

Rule 1
------

The file containing the VC entity shall contain only that entity, and the file containing the VCI package shall
contain only that package.

**Rationale**: This structure simplifies compliance testing, as each VC or VCI can be directly referenced by its
file name.

Rule 2
------

A VC shall have only **one** generic, the *handle*, and it shall be of a record type containing **private** fields.

**Rationale**: Using a record allows future updates to add and/or remove fields in the record without breaking
backward compatibility.

**Recommendation**: Mark the fields as private by using a naming convention and/or including comments. This minimizes
the risk of users accessing fields directly.

Rule 3
------

The VC handle shall be created by a function, the *constructor*, which shall have a name beginning with ``new``.

**Rationale**: Using a constructor removes the need for users to directly access the private fields of the handle
record. The naming convention also enables compliance tests to easily locate the constructor and verify it against
other applicable rules.

Rule 4
------

The VC constructor shall include an ``id`` parameter of type ``id_t`` to enable the user to specify the VC's identity.

**Rationale**: This gives users control over the namespace assigned to the VC.

Rule 5
------

The ``id`` parameter shall default to ``null_id``. If not overridden, ``id`` shall be assigned a value on the format
``<provider>:<VC name>:<n>``, where ``<n>`` starts at 1 for the first instance of the VC and increments with each
additional instance.

**Rationale**: This format ensures clear identification while preventing naming collisions when VCs from different
providers are combined.

Rule 6
------

All identity-supporting objects associated with the VC (such as loggers, actors, and events) shall be assigned an
identity within the namespace defined by the constructor’s ``id`` parameter.

**Rationale**: This gives users control over these objects and simplifies the association of log messages with a
specific VC instance.

Rule 7
------

All logging performed by the VC, including indirect logging (such that error logs from checkers), shall use the
VUnit logging mechanism.

**Rationale**: Using a unified logging mechanism ensures consistency and compatibility across logging outputs
from different VCs.

Rule 8
------

Communication with the VC shall be based on VUnit message passing, and the VC actor’s identity shall match the
``id`` parameter provided to the constructor.

**Rationale**: This ensures a consistent communication framework and enables the reuse of VCIs across multiple VCs.

Rule 9
------

All VCs shall support the sync interface.

**Rationale**: The ability to verify if a VC is idle and to introduce delays between transactions are frequently
needed features for VC users.

Rule 10
-------

The VC constructor shall include an ``unexpected_msg_type_policy`` parameter, allowing users to specify the action
taken when the VC receives an unexpected message type.

**Rationale**: This policy enables flexibility in handling situations where a VC actor, subscribed to another actor,
might receive unsupported messages, while VCs addressed directly should only receive supported messages.

Rule 11
-------

The standard configuration (of type ``std_cfg_t``), which includes the required parameters for the constructor, shall
be accessible by calling ``get_std_cfg`` with the VC handle.

**Rationale**: This enables reuse of common functions across multiple VCs.

Rule 12
-------

A VC shall keep the ``test_runner_cleanup`` phase entry gate locked as long as there are pending operations.

**Rationale**: Locking the gate ensures that the simulation does not terminate prematurely before all operations have
completed.
