.. @TODO change date but cannot be in the future or it wont show

.. post:: Jan 02, 2018
   :tags: VUnit
   :author: kraigher, lasplund
   :excerpt: 2

VUnit 3
=======
A new year has come and it is time for a third major update of VUnit.
The update contains a number of major enhancement to our VHDL libraries

Message Passing
---------------

We have improved the ease of use of the :ref:`com <com_user_guide>`
message passing library. Message creation is now very simple using
push/pop of any standard data type. We have also added better
debug-capabilities.

.. @TODO examples:

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
