.. @TODO change date but cannot be in the future or it wont show

.. post:: Jan 02, 2018
   :tags: VUnit
   :author: kraigher, lasplund
   :image: 1
   :excerpt: 1

VUnit 3.0
=========

.. figure:: VUnit3.0.png
   :alt: VUnit 3.0
   :align: center

A new year has come and it is time for a third major update of VUnit.
The update contains a number of major enhancement to our VHDL libraries

Message Passing
---------------

We have improved the ease of use of the :ref:`com <com_user_guide>`
message passing library. Message creation and parsing is now very simple using
push/pop of any standard data type together with message types.

A sending process pushes data into a message and sends it to the receiver, a
bus functional model (BFM) in this example.

.. code-block:: vhdl

  msg := new_msg(write_msg);
  push_integer(msg, address);
  push_std_ulogic_vector(msg, data);
  send(net, bfm, msg);

The message passing details would typically be wrapped into a procedure to provide a
more user friendly interface for the BFM

.. code-block:: vhdl

  write(net, address, data);

Message types are registered with `com` to get a system unique identifier.

.. code-block:: vhdl

  constant write_msg : msg_type_t := new_msg_type("write");

The type makes it easy for the receiver to handle incoming messages correctly.

.. code-block:: vhdl

  receive(net, bfm, msg);
  msg_type := message_type(msg);

  if msg_type = write_msg then
    address := pop_integer(msg);
    data := pop_std_ulogic_vector(msg);
    perform_pin_wiggling_on_bus_interface(address, data);
  elsif msg_type = read_msg then
    ...

We have also added better debug capabilities. It's possible to inspect the state of the
message passing system and trace messages can be enabled to see the dynamic behavior.

.. code-block:: console

      0 ps - vunit_lib:com -   TRACE - [2:- test sequencer -> memory BFM (read)] => memory BFM inbox
  10000 ps - vunit_lib:com -   TRACE - memory BFM inbox => [2:- test sequencer -> memory BFM (read)]
  20000 ps - memory BFM    -   DEBUG - Reading x"21" from address x"80"
  20000 ps - vunit_lib:com -   TRACE - [3:2 memory BFM -> test sequencer (read reply)] => test sequencer inbox
  30000 ps - vunit_lib:com -   TRACE - test sequencer inbox => [3:2 memory BFM -> test sequencer (read reply)]

For more information see the :ref:`com user guide <com_user_guide>`.


Verification Components
-----------------------

In VUnit 3 we release have a *beta*-version of a :ref:`verification
component <vc_library>` library. Using the improved ``com`` message
passing it is very easy to create advanced verification components and
we hope to get many pull requests from users for other bus types in
the future.

We say it is *beta* since we want to keep the door open to make
breaking changes as we learn more together with our users. The AXI
models are however already used in production environments.

Out of the box we provide the following verification components:
  - AXI read/write slaves
  - Memory model
  - AXI master
  - AXI stream
  - UART RX/TX
  - (B)RAM master

    .. @TODO examples

Logging
-------
VUnit 3 contains a number of logging framework enhancements that goes
hand in hand with the verification components.

- Better log source hierarchy support.

- Colorized output.

- Support for mocking loggers to make testing errors and failures from
  verification components trivial and fun.


  .. @TODO Add image of color logging here?
