.. _com_user_guide:

Communication Library
=====================

Introduction
------------

Communication (``com``) provides a high-level communication mechanism
based on the `actor model <http://en.wikipedia.org/wiki/Actor_model>`__.
The actor model is a mathematical model of computation in which
concurrent *actors* perform all computation. The only way actors can
communicate is by sending messages to each other and the message passing
is based on two important principles:

-  The sending actor only knows the name of the receiving actor. It
   doesn't know the location of the receiver or how a message gets
   there.
-  Communication is asynchronous. The sender doesn't know when the
   receiver will read the message.

Based on these principles and a few more it's possible to construct more
advanced communication patterns. However, the actor model alone has
focus on the essentials of communication, the actors exchanging
information and the information being exchanged. Everything else is
superfluous.

This purity along with the concurrency of the actors makes the model a
very suitable base for a high-level communication mechanism in VHDL.
Concurrent statements like processes and components are the actors in a
VHDL simulation and the messages are variables of a type suitable for
the information being exchanged.

Setup
-----

Message passing is not a core functionality of unit testing so ``com``
is provided as an optional add-on to VUnit. It is compiled to the
``vunit_lib`` library with the ``add_com`` method in your Python script

.. code-block:: python

    ui = VUnit.from_argv()
    ui.add_com()

The VHDL functionality is provided to your testbench with the
``com_context``.

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

Basic Message Passing
---------------------

To send a message we must first create an actor for the sender and then
find the actor of the receiver. These actors are then used when sending
a message as shown in the example below.

.. code-block:: vhdl

      proc_1: process is
        variable self : actor_t := create("proc_1");  -- Create an actor for myself
        variable proc_2 : actor_t := find("proc_2");  -- Find the receiver
        variable receipt : receipt_t;       -- Send receipt
      begin
        send(net, proc_2, "Hello proc_2!", receipt);
        check_relation(receipt.status = ok);
        wait;
      end process proc_1;

The returned receipt contains, among other things, status for the send
and the expected value is ``ok``. ``net`` is the abstract network over
which messages are sent. Ideally this shouldn't be part of the procedure
call but since ``net`` is a signal and the procedure is defined within a
package it has to be among the parameters if the procedure is to drive
the signal. Note that the self variable isn't used and could have been
excluded. It will be used in later examples where the sender can't be
anonymous.

Below is a basic receiver for the message above.

.. code-block:: vhdl

      proc_2: process is
        variable self : actor_t := create("proc_2");
        variable message  : message_ptr_t;
      begin
        receive(net, self, message);
        check_relation(message.status = ok);
        report "Received " & message.payload.all;
        wait;
      end process proc_2;

Note that communication is asynchronous. The ``send`` procedure takes no
physical simulation time, only delta cycles, and you can also send as
many messages you like (limited by the host memory) before the receiver
starts receiving messages. However, the receiver will always get the
messages in the order they were sent.

Note also that no information about the location of the actors or
details on the message transport is exposed. This simplifies refactoring
of the code. For example, if ``proc_1`` and ``proc_2`` are in the same
file and you decide to package one of them as an entity and move it into
another file you don't have to change anything about the communication.

The default behaviour of the ``receive`` procedure above is to block
until a message arrives but it can also be setup with a timeout. If you
want the receiver to poll for messages you set the timeout to zero.

.. code-block:: vhdl

      proc_2: process is
        variable self : actor_t := create("proc_2");
        variable message  : message_ptr_t;
      begin
        receive(net, self, message, 1 ns);
        case message.status is
          when ok =>
            report "Received " & message.payload.all;
          when timeout =>
            report "Timed out waiting for a message";
          when others =>
            check_failed("Reception error - " & to_string(message.status));
        end case;
        wait;
      end process proc_2;

Creating and finding actors is often done at the beginning of a process
at time zero. This means that there is a potential race condition, i.e.
the ``find`` of one process is called before the the actor searched for
has been created. The default behaviour is that ``com`` does a
*deferred* creation of an actor in these situations. The deferred state
is then removed when the actor is created. It is possible to perform
actions on a deferred actor when it is the "other" actor, for example
sending **to** an actor. However, it is not possible to perform actions
from a deferred actor, for example sending **from** it. The risk with
this approach is if you do a ``find`` with a misspelled actor. Messages
sent to the resulting deferred actor will never be read by anyone.

The default behaviour with deferred creation can be overridden by
calling ``find("actor_name", enable_deferred_creation => false);``. Such
a call will return ``null_actor_c`` if the searched actor hasn't been
created. It's also possible to call ``num_of_deferred_creations`` and
verify that it returns zero when you expect all involved actors to be
created.

In the examples so far the message has been a string and string is the
only message type that ``com`` can handle. Rather than having the user
define overloaded versions for every subprogram and message type needed
``com`` provides functionality for encoding other types to string before
the message is sent and then, on the receiving side, decode back to the
original type again. For example, sending an integer can be done like
this.

.. code-block:: vhdl

        send(net, receiver, encode(my_integer), receipt);

which can be received like this.

.. code-block:: vhdl

        my_integer := decode(message.payload.all);
        report "Received " & to_string(my_integer);

``com`` has support for around 25 native VHDL and IEEE types. These can
be used as primitives when building codecs for custom composite types.
For example, an encoder for a custom record type can be built as a
simple concatenation of the encoded record elements. However, ``com``
can also generate codecs for your custom enumeration, array, and record
types. For example, the `card shuffler
example <../../../examples/vhdl/com/test/tb_card_shuffler.vhd>`__ uses the
following package.

.. code-block:: vhdl

    package msg_types_pkg is
      type rank_t is (ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king);
      type suit_t is (spades, hearts, diamonds, clubs);
      type card_t is record
        rank : rank_t;
        suit : suit_t;
      end record card_t;

      type card_msg_type_t is (load, received);
      type card_msg_t is record
        msg_type : card_msg_type_t;
        card     : card_t;
      end record card_msg_t;

      type reset_msg_type_t is (reset_shuffler);
      type reset_msg_t is record
        msg_type : reset_msg_type_t;
      end record reset_msg_t;

      type request_msg_type_t is (get_status);
      type request_msg_t is record
        msg_type   : request_msg_type_t;
        checkpoint : natural;
      end record request_msg_t;

      type reply_msg_type_t is (get_status_reply);
      type reply_msg_t is record
        msg_type       : reply_msg_type_t;
        checksum_match : boolean;
        matching_cards : boolean;
      end record reply_msg_t;

    end package msg_types_pkg;

Encoders for these types are generated if you add the following to the
Python script

.. code-block:: python

    tb_shuffler_lib = ui.add_library('tb_shuffler_lib')
    tb_shuffler_lib.add_source_files(join(dirname(__file__), 'test', '*.vhd'))
    pkg = tb_shuffler_lib.package('msg_types_pkg')
    pkg.generate_codecs(codec_package_name='msg_codecs_pkg')

The last two lines will take the types in ``msg_types_pkg``, generate
codecs and place them in ``msg_codecs_pkg``. Moreover, records with an
initial element named ``msg_type`` that is of an enumerated type get
special treatment. For each value of the enumerated type there will be
an encoder function named after that value with the rest of the elements
as parameters. So instead of writing

.. code-block:: vhdl

    my_card_msg := (load, (ace, spades));
    send(net, receiver, encode(my_card_msg), receipt);

you can write

.. code-block:: vhdl

    send(net, receiver, load((ace, spades)), receipt);

which makes the intention of the message more clear.

**Note1:** The encoder function also has an alias with a ``_msg`` suffix
(``load_msg`` in the previous example). This must currently be used with
Aldec's simulators if the function has no input parameters. The reason
is that the normal name (``load``) is confused with the enumeration
literal with the same name.

**Note2:** Codec generation for unconstrained arrays with composite
element types is not supported for Aldec's simulators. This limitation
will be removed as soon as some issues with these tools have been fixed.

You also get a ``get_msg_type`` function which will return the type of a
message considering all message types defined in the package. This
provides a convenient way to select the correct decoder on the receiving
side. Here's an example.

.. code-block:: vhdl

          receive(net, self, message);
          case get_msg_type(message.payload.all) is
            when load =>
              card_msg := decode(message.payload.all);
              -- Do something with the card
            when received =>
              -- Decode this message type and take action
            when get_status =>
              -- Decode this message type and take action
            when reset_shuffler =>
              -- Decode this message type and take action
            when others =>
              check_failed("Message type not supported");
            end case;

Sometimes the encode/decode functions used in the code are ambiguous to
the compiler. To handle this, all built-in and generated encode/decode
functions have an alias with a prefix of ``encode_/decode_``, for example
``encode_card_t``.

Publisher/Subscriber Pattern
----------------------------

Sometimes a message needs to be sent to many receivers and this can of
course be achieved with multiple calls to the ``send`` procedure.
However, in many of these cases the sender isn't interested in who the
receivers are, it just want to broadcast information to anyone
interested. If this is the case it's inconvenient to add a new ``send``
call to the sender for every new receiver. This is called the
publisher/subscriber pattern and ``com`` has dedicated functionality to
support it.

An example of this pattern can be found in the `card shuffler
example <../../../examples/vhdl/com/test/tb_card_shuffler.vhd>`__. There the
test runner publishes commands to load cards into the card shuffler.
These commands are received by a driver which translates the commands to
the pin wiggling understood by the card shuffler. The commands are also
received by the scoreboard such that it can compare what is being sent
into the card shuffler with what is sent out and from that determine if
a correct shuffling has taken place.

A ``publish`` is the same as a ``send`` with the difference that no
receiver is specified, it can't be anonymous, and that a status is
returned instead of a receipt. The difference between a receipt and a
status is that the receipt contains status as we've seen before but also
a message ID which is used for the client/server pattern described later
on. The ID is unique to a message but a publish may result in zero or
many messages. Moreover, it does not make sense to combine publishing
with the client/server pattern so the message ID has been excluded from
the ``publish`` procedure. A publish must be made with the publisher
actor as a parameter so that ``com`` can find the subscribers.

.. code-block:: vhdl

    publish(net, self, load((rank, suit)), status);

An actor interested in what's published call the ``subscribe``
procedure. Both the driver and the scoreboard have this piece of code.

.. code-block:: vhdl

    subscribe(self, find("test runner"), status);

Published messages are then received with the normal ``receive``
procedure. It's also possible for an actor to unsubscribe from what's
being published.

.. code-block:: vhdl

    unsubscribe(self, find("test runner"), status);

Client/Server Pattern
---------------------

Messages sent are often requests for some information owned by the
receiver. This is called the client/server pattern and is supported in a
number of ways.

-  The server needs a way to reply to a request from a client which it
   has no prior knowledge of. This is achieved by using
   ``message.sender`` on an incoming message. This also means that the
   ``send`` call making the request can't be anonymous.
-  The server also needs a way to specify which request it's replying to
   since replies may be done out of order. To do this the server
   extracts a unique message ID from the client request message and use
   that as a reference when sending the reply.

   .. code-block:: vhdl

       requesting_actor := message.sender;
       request_id       := message.id;
       -- Prepare reply_message based on request in message.payload
       reply(net, self, requesting_actor, request_id, reply_message, receipt);

   So a ``reply`` procedure is just like a ``send`` procedure with the
   addition of the request ID.

-  The client making the request can also wait for the reply to that
   request ignoring any other message that may arrive before the reply.

   .. code-block:: vhdl

       send(net, self, find("scoreboard"), request_message, receipt);
       receive_reply(net, self, receipt.id, reply_message);

   The difference between ``receive_reply`` and a normal ``receive`` is
   the ID for the request message which reply we are waiting for. Any
   message ignored by ``receive_reply`` will still be available by
   calling the normal ``receive`` procedure later on. When the ``send``
   and the ``receive_reply`` calls are made back-to-back they can be
   replaced by a single ``request`` call.

   .. code-block:: vhdl

       request(net, self, find("scoreboard"), request_message, reply_message);

Synchronous Communication
-------------------------

The actor model as well as ``com`` are based on asynchronous
communication but can still be used for synchronous communication. There
are basically two ways:

1. You can use the client/server pattern and have the receiver send an
   acknowledge message back to the sender which blocks waiting for that
   acknowledge using ``receive_reply`` or ``request``. For the case when
   the acknowledge message contains no more information than if the
   request was handled with positive or negative result there is a
   special ``reply`` procedure called ``acknowledge`` that takes a
   ``positive_ack`` boolean input instead of a string message. There are
   also matching ``request`` and ``receive_reply`` procedures working
   with this boolean information.
2. It is also possible to limit the number of unread messages that an
   receiver can have. This mechanism can be used to limit the amount of
   memory used in the simulation but can also be used for
   synchronization. If the limit is reached a new send to that receiver
   will block with an optional timeout. Setting the limit to one means
   that the receiver must read the first message before the sender can
   get another one through. To set a limit on the receiver you add a
   second parameter to the create call.

   .. code-block:: vhdl

       variable self : actor_t := create("proc_1", 1);

When using ``publish`` any subscriber which reached its limit will
miss that message. The reason for skipping these subscribers is that
we do not want the publisher to block since that would create
dependencies between the publisher and its subscribers as well as
between the subscribers. The latter is because subscribers "after" the
one causing the blocking will have the message delayed. This is not
desirable since the pattern is used when the publisher doesn't
have/want any knowledge of the subscribers and the subscribers may
also be unaware of each other. A subscriber can use the
``num_of_missed_messages`` function to get the total number of
messages missed.

Message Debugging
-----------------

When debugging a simulation containing messages it helps if those
messages can be easily read and ``com`` can help out in two different
ways. One is to add trace messages wherever necessary using the VUnit
logging functionality together with the ``to_string`` function for the
message/data type being sent. The automatic codec generation provided
for custom message types also provide ``to_string`` functions for these
types.

-  ``to_string`` on enumerated types will return the string for the
   values in the type just as you defined them.
-  ``to_string`` on a record will return a comma-separated string of
   each element's ``to_string`` result enclosed in parenthis. For
   example, ``to_string`` for the ``card_t`` type used in previous
   examples will return something like ``(ace, spades)``
-  ``to_string`` on an array will return a comma-separated string just
   like records but the three first elements are special. The first
   element is the left attribute of the array, the second is the right
   attribute, and the third is the ascending attribute (true or false).

The second debug support provided by ``com`` is that you can use debug
codecs instead of those being used by default. The default codecs
basically take a binary representation of each scalar type, split that
into bytes, and encode each byte with the corresponding character in the
ASCII table. Composites are encoded by concatenating its scalar
primitives. This approach to encoding results in short strings and gives
better message passing run-time performance. The debug codecs takes
another approach by simply encode messages using the ``to_string``
function. Message payloads now becomes readable in the simulation but at
the expense of longer strings which lowers the performance. You can
permanently enable the debug codecs in your Python script like this.

.. code-block:: python

    ui = VUnit.from_argv()
    ui.add_com(use_debug_codecs=True)

You can also enable the debug codecs when calling your script.

.. code-block:: console

    python run.py --use-debug-codecs
