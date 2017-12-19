.. _bfm_library:

Bus Functional Model Library
============================

The VUnit Bus Functional Model Library (BFM) contains a number of
:ref:`verification components <verification_components>` (VC) as well
as a set of utilities for writing your own verification
component. Verification components allow a better overview in the test
bench by raising the abstraction level of bus transactions. Even if
you do not need the advanced features that VCs offer you may still
benefit from using per-verified models of an AXI-bus instead of
re-implementing it yourself.

Included verification components:

- AXI-Lite master
- AXI read slave
- AXI write slave
- AXI stream master
- AXI stream slave
- Memory model
- RAM master
- UART master
- UART slave

In addition to VCs VUnit also has the concept of verification
component interfaces (VCI). A single VC typically implements several
VCIs. For example an AXI-lite VC or RAM master VC can support the same
generic bus master and synchronization VCI while also supporting their
own bus specific VCIs.

The main benefit of generic VCIs is to reduce redundancy between VCs
and allow the user to write generic code that will work regardless of
the specific VC instance used. For example control registers might be
defined as a RAM-style bus in a submodule but be mapped to an AXI-lite
interface on the top level. The same testbench code for talking to the
submodule can be used in both the submodule test bench as well as the
top level test bench regardless of the fact that two different VCs
have been used. Without generic VCIs copy pasting the code and
changing the type of read/write procedure call would be required.

Generic VCIs included:

:ref:`Bus master <bus_master_vci>`
  Generic read and write of bus with address and byte enable.

Stream
  Push and pop of data stream without address.

:ref:`Synchronization <sync_vci>`
  Wait for time and events.


.. _verification_components:

Verification Components
-----------------------
A verification component (VC) is an entity that is normally connected
to the DUT via a bus signal interface such as AXI-Lite. The main test
sequence in the test bench sends messages to the VCs that will then
perform the actual bus signal transactions. The benefit of this is
both to raise the abstraction level of the test bench as well as
making it easy to have parallel activity on several bus interfaces.

A VC typically has an associated package defining procedures for
sending to and receiving messages from the VC. Each VC instance is
associated with a handle that is created in the test bench and set as
a generic on the VC instantiation. The handle is given as and arguemnt
to the procedure calls to direct messages to the specfic VC instance.


.. toctree::
   :maxdepth: 1

   vci/bus_master
   vci/sync
