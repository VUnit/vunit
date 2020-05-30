.. _vc_library:

Verification Component Library
===============================

.. note:: This library is released as a *BETA* version. This means
          non-backwards compatible changes are still likely based on
          feedback from our users.

The VUnit Verification Component Library (VCL) contains a number of
useful :ref:`Verification Components <verification_components>` (VC)
as well as a set of utilities for writing your own verification
component. Verification components allow a better overview in the test
bench by raising the abstraction level of bus transactions. Even if
you do not need the advanced features that VCs offer you may still
benefit from using pre-verified models of an AXI-bus instead of
re-implementing it yourself.

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

In addition to VCs VUnit also has the concept of :ref:`Verification
Component Interfaces <verification_component_interfaces>` (VCI). A
single VC typically implements several VCIs. For example an AXI-lite
VC or RAM master VC can support the same generic bus master and
synchronization VCI while also supporting their own bus specific VCIs.

.. TIP:: The main benefit of generic VCIs is to reduce redundancy between
   VCs and allow the user to write generic code that will work regardless
   of the specific VC instance used. For example control registers might be
   defined as a RAM-style bus in a submodule but be mapped to an AXI-lite
   interface on the top level. The same testbench code for talking to the
   submodule can be used in both the submodule test bench as well as the
   top level test bench regardless of the fact that two different VCs
   have been used. Without generic VCIs copy pasting the code and
   changing the type of read/write procedure call would be required.

Neither a VC or a VCI, there is the :ref:`memory model <memory_model>`
which is a model of a memory space such as the DRAM address space in a
computer system. The memory mapped slave VCs such as AXI and Wishbone
make transactions against the memory model which provides access
permissions, expected data settings as well as the actual buffer for
reading and writing data.

.. toctree::
   :maxdepth: 1
   :hidden:

   memory_model

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
associated with a handle that is created by a _constructor_ function
in the test bench and set as a generic on the VC instantiation.
The handle is given as an argument to the procedure calls to direct
messages to the specfic VC instance.

.. _verification_component_interfaces:

Verification Component Interfaces
---------------------------------

A verification component interface (VCI) is a procedural interface to
a VC. A VCI is defined as procedures in a package file. Several VCs can
support the same generic VCI to enable code re-use both for the users
and the VC-developers.

List of VCIs included in the main repository:

* :ref:`Bus master <bus_master_vci>`: generic read and write of bus with address and byte enable.
* :ref:`Stream <stream_vci>`: push and pop of data stream without address.
* :ref:`Synchronization <sync_vci>`: wait for time and events.

.. toctree::
   :maxdepth: 1
   :hidden:

   vci

VC and VCI Compliance Testing
-----------------------------

VUnit also provides a set of compliance tests to help VC and VCI developers adhere
to good design principles. These rules aim at creating flexible, reusable, interoperable
and future proof VCs and VCIs.

----

**Rule 1**
  The file containing the VC entity shall only contain one entity and the file containing the VCI package shall only contain one package.

**Rationale**
  The VC/VCI can be referenced by file name which makes compliance testing simpler.

----

**Rule 2**
  The name of the function used to create a new instance handle for a VC, aka the constructor, shall start with ``new_``.
**Rationale**
  Makes it easier for the compliance test to automatically find a constructor and evaluate that with respect to the other applicable rules.

----

**Rule 3**
  A VC constructor shall have a ``logger`` parameter giving the user the option to specify the logger to use for VC reporting.
**Rationale**
  It enables user control of the logging, for example enabling debug messages.

----

**Rule 4**
  A VC constructor shall have a ``checker`` parameter giving the user the option to specify the checker to use for VC checking.
**Rationale**
  It enables user control of the checking, for example setting properties like the stop-level (without affecting the logger used above).

----

**Rule 5**
  A VC constructor shall have an ``actor`` parameter giving the user the option to specify the actor to use for VC communication.
**Rationale**
  It enables user control of the communication, for example setting name for better trace logs.

----

**Rule 6**
  A VC constructor shall have an ``unexpected_msg_type_policy`` parameter giving the user the option to specify the action taken when the VC receives an unexpected message type.
**Rationale**
  A VC actor setup to subscribe to another actor may receive messages not relevant for its operation. OTOH, VCs just addressed directly should only recieve messages it can handle.

----

**Rule 7**
  A VC constructor shall have a default value for all required parameters above.
**Rationale**
  Makes it easier for the user if there is no preference on what to use.

----

**Rule 8**
  The default value for the logger parameter shall not be ``default_logger``.
**Rationale**
  Using a logger more associated with the VC makes the logger output easier to understand.

----

**Rule 9**
  The default value for the checker parameter shall not be ``default_checker``.
**Rationale**
  Using a checker more associated with the VC makes the checker output easier to understand.

----

**Rule 10**
  All fields in the handle returned by the constructor shall start with ``p_``.
**Rationale**
  All field shall be considered private and this is a way to emphasize this. Keeping them private makes updates easier without breaking backward compatibility.

----

**Rule 11**
  The standard configuration, ``std_cfg_t``, of a VC consisting of the required parameters to the constructor shall be possible to get from the handle using a call to ``get_std_cfg``.
**Rationale**
  Makes it possible to reuse operations such as ``get_logger`` between VCs.

----

**Rule 12**
  A VC shall only have one generic.
**Rationale**
  Representing a VC with a single object makes it easier to handle in code. Since all fields of the handle are private future updates have less risk of breaking backward compatibility.

----

**Rule 13**
  All VCs shall support the sync interface.
**Rationale**
  Being able to check that a VC is idle and to add a delay between transactions are commonly useful operations for VC users.

----

Compliance testing is done separately for the VC and the VCI and each test consists of two parts. One part tests the code by parsing it and the other part tests the code by running a VHDL testbench.

The VHDL testbenches cannot be automatically created because of:

* A VC constructor can have VC specific parameters without default values
* A VC port list can constain unconstrained ports

These issues are solved by creating a templates for the VHDL testbenches. The template is created by calling the compliance_test.py script (--help for instructions). Some rules are checked in this process and any violation is reported.
When all violations have been fixed the script will generate a template file which needs to modified manually according to the instructions in the template file.

The run.py file verifying the VC and the VCI can then add compliance tests by using the VerificationComponentInterface and VerificationComponent classes. These classes provides methods to generate the full VHDL testbenches from the
templates and some extra parameters.

.. code-block:: python

    # Find the VCI for the Avalon sink VC located in the avalon_stream_pkg package which has been added
    # to library lib (lib.add_source_files). The return type for the VC constructor, avalon_sink_t, which
    # allow the constructor to be found analyzed.
    avalon_sink_vci = VerificationComponentInterface.find(
        lib, "avalon_stream_pkg", "avalon_sink_t"
    )

    # Add a VCI compliance testbench to library test_lib. The generated testbench will be saved in the
    # compliance_test directory and the final path identifies the previously generated testbench template
    avalon_sink_vci.add_vhdl_testbench(
        test_lib,
        join(root, "compliance_test"),
        join(root, ".vc", "avalon_stream_pkg", "tb_avalon_sink_t_compliance_template.vhd")
    )

    # Find the Avalon_sink VC located in the lib library
    avalon_sink_vc = VerificationComponent.find(lib, "avalon_sink", avalon_sink_vci)

    # Add a VC compliance testbench to library test_lib. The generated testbench will be saved in the
    # compliance_test directory and the final path identifies the previously generated testbench template
    avalon_sink_vc.add_vhdl_testbench(
        test_lib,
        join(root, "compliance_test"),
        join(root, ".vc", "tb_avalon_sink_compliance_template.vhd")
    )


The Avalon sink test suite will now have a number of extra test cases verifying that it is compliant

.. code-block:: console

    ==== Summary ============================================================================================================================
    pass test_lib.tb_avalon_sink_t_compliance.Test standard configuration                                                 (1.5 seconds)
    pass test_lib.tb_avalon_sink_t_compliance.Test handle independence                                                    (0.7 seconds)
    pass test_lib.tb_avalon_sink_t_compliance.Test default logger                                                         (0.8 seconds)
    pass test_lib.tb_avalon_sink_t_compliance.Test default checker                                                        (0.7 seconds)
    pass test_lib.tb_avalon_sink_compliance.Test that sync interface is supported                                         (0.8 seconds)
    pass test_lib.tb_avalon_sink_compliance.Test that the actor can be customised                                         (0.8 seconds)
    pass test_lib.tb_avalon_sink_compliance.accept_unexpected_msg_type.Test unexpected message handling                   (0.8 seconds)
    pass test_lib.tb_avalon_sink_compliance.fail_unexpected_msg_type_with_null_checker.Test unexpected message handling   (0.8 seconds)
    pass test_lib.tb_avalon_sink_compliance.fail_unexpected_msg_type_with_custom_checker.Test unexpected message handling (0.8 seconds)
    =========================================================================================================================================
    pass 9 of 9
    =========================================================================================================================================
    Total time was 7.6 seconds
    Elapsed time was 7.7 seconds
    =========================================================================================================================================
    All passed!
