.. _com_user_guide:

################################
Communication Library User Guide
################################

************
Introduction
************

The VUnit communication library (``com``) provides a high-level communication mechanism
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

By extending the basic communication provided by the actor model ``com`` can also provide
synchronous communication and some more advanced communication patterns.

*****
Setup
*****

Message passing is not a core functionality of unit testing so ``com``
is provided as an optional add-on to VUnit. It is compiled to the
``vunit_lib`` library with the ``add_com`` method in your Python script

.. code-block:: python

    prj = VUnit.from_argv()
    prj.add_vhdl_builtins()
    prj.add_com()

The VHDL functionality is provided to your testbench with the
``com_context``.

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

*********************
Basic Message Passing
*********************

Sending and Receiving
---------------------

To send a message we must first create an actor for the receiver. This is done with the ``new_actor``
function which takes an optional name parameter. If no name is given the actor will be assigned
a name internally on the format ``_actor_<n>`` where ``n`` denotes an integer unique to the
actor.

.. code-block:: vhdl

  constant my_receiver : actor_t := new_actor("my receiver");

Internally an identity (see :ref:`identity package <id_user_guide>`) will be created for each actor
and it is also possible to create an actor directly from an identity.

  constant my_receiver_id : id_t := get_id("my receiver");
  constant my_receiver : actor_t := new_actor(my_receiver_id);

To send a message to the receiver the sender must have access to the value of the ``my_receiver`` constant.
If the receiver made ``my_receiver`` publically available, for example with a package, it can be accessed
directly. If not, it can be found with the ``find`` function providing it has been given an explict name.

.. code-block:: vhdl

  constant found_receiver : actor_t := find("my receiver");

or

.. code-block:: vhdl

  constant found_receiver : actor_t := find(my_receiver_id);

The next step is to create a message to send and we start by creating an empty message

.. code-block:: vhdl

  msg := new_msg;

where ``msg`` is a variable of type ``msg_t``. Information is added to the message by pushing objects of
different types into it.

.. code-block:: vhdl

  push_string(msg, "10101010");
  push(msg, my_integer);

``com`` supports pushing of all native and standardized IEEE types. In case there is no ambiguity you can just
do ``push``, otherwise you have to use the more specific alias ``push_<type>`` as exemplified above.

To send the created message to the receiver you call the ``send`` procedure

.. code-block:: vhdl

  send(net, my_receiver, msg);

``send`` is asynchronous and takes no simulation time, only delta cycles. Messages will be stored in the receiver inbox
until the receiver is ready to receive.

``net`` is a network connecting actors and it is used to signal that an event has occurred, for example that a message
has been sent. The event notifies all connected actors that something has happened which they may be interested in.
For example, the event created when sending a message will wake up all receivers such that they can see if they are the
receiver for the message.

An actor waiting for a message uses the receive procedure

.. code-block:: vhdl

  receive(net, my_receiver, msg);

This procedure returns immediately if there are pending message(s) in the receiver's inbox or blocks until the first
message arrives. The returned message contains the oldest incoming message and its information can be retrieved using
``pop`` functions. The code below will verify that the message has the expected content using the VUnit
:ref:`check_equal <equality_check>` procedure.

.. code-block:: vhdl

  check_equal(pop_string(msg), "10101010");
  my_integer := pop(msg);
  check_equal(my_integer, 17);

Just like ``push`` there are both ``pop`` functions and more verbose aliases on the form ``pop_<type>``.

Objects are always popped from the message in the same order they were pushed into the message and once all objects
have been popped the message is empty. If you want to keep a message for later you can make a copy before popping.

.. code-block:: vhdl

  msg_copy := copy(original_msg);



Message Types
-------------

In the example above the sender and the receiver exchanged one type of message (a string followed by an integer) but
the normal use case is that a receiver can handle several types of messages. For example, if the receiver is a bus
functional model (BFM) connected to a memory bus it would be able to handle both read and write messages.

Rather than using a regular type as the message type, for example the string ``"write"`` for a write message, ``com``
provides a special message type.

.. code-block:: vhdl

  constant write_msg : msg_type_t := new_msg_type("write");

``"write"`` is just a description of the message type and not a unique identifier. Even if we have two independently
created BFMs, both providing the constant above in their own packages, they would be given different values by the
``new_msg_type`` function. This means that we can safely create the different types of write messages without any risk
of mistaking one for the other.

.. code-block:: vhdl

  msg := new_msg(memory_bfm_pkg.write_msg);
  push(msg, my_unsigned_address);
  push(msg, my_std_logic_vector_data);
  send(net, memory_bfm_pkg.actor, msg);

The receiver starts by looking at the message type and then handles the message types it recognizes.

.. code-block:: vhdl

  message_handler: process is
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable address : unsigned(7 downto 0);
    variable data : std_logic_vector(7 downto 0);
    variable memory : integer_vector(0 to 255) := (others => 0);
  begin
    receive(net, actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = write_msg then
      address := pop(request_msg);
      data := pop(request_msg);
      memory(to_integer(address)) := to_integer(data);
    end if;
  end process;

Normally a BFM would never be exposed to a write message aimed for another BFM but under certain cases it can happen.
For example when using the :ref:`publisher\/subscriber pattern <publisher_subscriber>` described later.
A typical BFM would also provide a write transaction procedure which hides the message passing details (creating
message, pushing data, and sending). That gives an extra level of type safety (and readability).

.. code-block:: vhdl

  memory_bfm_pkg.write(net, my_unsigned_address, my_std_logic_vector_data);

If you do not expect the receiver to receive messages of a type it can't handle you can add this else statement

.. code-block:: vhdl

  else
    unexpected_msg_type(msg_type);
  end if;

which will cause an unrecognize message to fail the testbench.


Message Ownership
-----------------

The sender of a message is the owner of that message while it's being created. As soon as the ``send`` procedure is
called that ownership is handed over to the receiver and the message passed to the ``send`` call can no longer be used
to retrieve the information you pushed into it. If you need to keep the message information you can make a copy
before calling ``send``.

Since memory is allocated whenever you push to a message its important
that the receiver side deallocates that memory to avoid memory leaks. This can be done explicitly by deleting the
message.

.. code-block:: vhdl

  delete(msg);

However, the typical receiver is a looping process that calls the ``receive`` procedure as soon as the previous message
has been handled. To simplify the design of the such a receiver the ``delete`` procedure is called first in the
``receive`` procedure to delete the message from the previous loop iteration.


Replying to a Message
---------------------

Replying to a message is done with the ``reply`` procedure. Below is the previous message handler process which has
been updated to also handle read request messages. Every such message results in a reply message targeting the
requesting actor.

.. code-block:: vhdl

  message_handler: process is
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable address : unsigned(7 downto 0);
    variable data : std_logic_vector(7 downto 0);
    variable memory : integer_vector(0 to 255) := (others => 0);
  begin
    receive(net, actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = write_msg then
      address := pop(request_msg);
      data := pop(request_msg);
      memory(to_integer(address)) := to_integer(data);

    elsif msg_type = read_msg then
      address := pop(request_msg);
      data := to_std_logic_vector(memory(to_integer(address)), 8);
      reply_msg := new_msg(read_reply_msg);
      push(reply_msg, data);
      reply(net, request_msg, reply_msg);

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

Just like the ``send`` procedure ``reply`` will hand message ownership to the receiver.

Receiving a Reply
-----------------

If you want to await a specific message like the reply to a request message you can use the ``receive_reply``
procedure. Below is a read procedure for our memory BFM.

.. code-block:: vhdl

  procedure read(
    signal net : inout event_t;
    constant address : in unsigned(7 downto 0);
    variable data : out std_logic_vector(7 downto 0)) is
    variable request_msg : msg_t := new_msg(read_msg);
    variable reply_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    push(request_msg, address);
    send(net, actor, request_msg);
    receive_reply(net, request_msg, reply_msg);
    msg_type := message_type(reply_msg);
    data := pop(reply_msg);
  end;

``receive_reply`` will block until the specified message is received. All other incoming messages will be ignored but
can be retrieved later. Note that we didn't need a message type for the reply messages, the read procedure just
throws it away. However, we will see later that including it can be helpful when debugging a communication system.

Sending a request and directly receiving the reply is a common sequence of calls so it has been given a dedicated
``request`` procedure. The two lines above can be replaced by

.. code-block:: vhdl

  request(net, actor, request_msg, reply_msg);

Another approach to the read procedure is to think of it as two steps. The first step sends the the non-blocking read
request and the second waits to get the requested data. The link between the two is the request message. This message
is sometimes called a future since it represents the requested data that will be available in the future. Splitting
blocking procedures like this allow you to initiate several concurrent transactions on different DUT interfaces or
perform other tasks while waiting for the replies.

.. code-block:: vhdl

  memory_bfm_pkg.non_blocking_read(net, address => x"80", future => future1);
  some_other_bfm_pkg.non_blocking_transaction(net, some_input_parameters, future2);

  <Do other things>

  memory_bfm_pkg.get(net, future1, data);
  some_other_bfm_pkg.get(net, future2, requested_information);

Signing Messages
----------------

So far all request messages have been anonymous, I've only created an actor for the receiving part. In these situations
the receiver ``reply`` call can't send a reply back to the sender so the reply message is placed in the receiver
outbox. The ``receive_reply`` procedure called by the sender knows that the request message was anonymous and waits
for the reply to appear in the receiver outbox instead of its own inbox.

Some communication patterns, for example the publisher/subscriber pattern, requires that all messages
are signed. To sign a message you can provide the sending actor when the message is created.

.. code-block:: vhdl

  msg := new_msg(sender => sending_actor);

Sending/Receiving to/from Multiple Actors
-----------------------------------------

The ``message_handler`` process presented above had a single actor. However, the actor model is not limited to have one
actor for each concurrently running process. A process may have several actors, each representing some other object
like a channel. A typical receiver in such a design needs to act on messages from several actors and to support that
you can call ``receive`` with an array of actors rather than a single actor. If several actors have messages the
procedure will return the oldest message from the leftmost actor with a non-empty inbox.

.. code-block:: vhdl

  receive(net, actor_vec_t'(channel_1, channel_2), msg);

It's also possible to send a message to multiple receiving actors. Just call ``send`` with an array of receivers.

.. code-block:: vhdl

  send(net, actor_vec_t'(receiver_1, receiver_2), msg);

There is no shared ownership of ``msg`` once it's sent. The sender loses ownership and each receiver get its own
copy.

*************************
Synchronous Communication
*************************

Message passing based on the actor model is inherently asynchronous in nature. Sending a message takes no time which
means that the sender can send any number of messages before the receiver starts processing the first one. Transactions
requesting a reply, like the read transaction presented before, will naturally break this flow of unprocessed messages
by blocking while waiting for a reply. Sometimes it's also useful to synchronize the sender and receiver on
transactions which initiate an action without expecting a reply, a write transaction for example. To do that we can
create a reply message with a positive or negative acknowledge to signal the completion of the transaction or the
failure to complete the request. Rather than doing that explicitly you can use one of the convenience procedures that
``com`` provides.

Instead of using the ``reply`` procedure with a reply message the receiver can use ``acknowledge`` with a
positive/negative response in the form of true/false boolean as the third parameter

.. code-block:: vhdl

  acknowledge(net, request_msg, positive_ack);

On the sender side there is a matching ``receive_reply`` procedure that will return that boolean.

.. code-block:: vhdl

  receive_reply(net, msg, positive_ack);

There is also a ``request`` procedure to be used in conjunction with ``acknowledge``.

.. code-block:: vhdl

  request(net, actor, msg, positive_ack);

Another approach to synchronization is to limit the number of unprocessed messages that a
receiver can have in its inbox. If the limit is reached, a new send to that receiver will block.
The default inbox size is ``integer'high`` but it can be set to some other value when the actor is created.

.. code-block:: vhdl

  constant my_actor : actor_t := new_actor("my actor", inbox_size => 1);

It's also possible to resize the inbox of an already created actor.

.. code-block:: vhdl

  resize(my_actor, new_size => 2);

Reducing the size below the number of messages in the inbox will cause a run-time failure.

A third way to synchronize actors is to have a dedicated message for that purpose but without any information exchange.
The message exchange will just be an indication that the receiver is idling waiting for new messages.

.. code-block:: vhdl

  request_msg := new_msg(wait_until_idle_msg);
  request(net, actor_to_synchronize, request_msg, reply_msg);

The sender will block on the ``request`` call until the actor to synchronize has replied and the two actors becomes
synchronized. Since there is no information exchange there is no need to pop the reply message.

The actor to synchronize will have to add an if statement branch to handle the new message type. Below I've extended
the message handling of the previous BFM example.

.. code-block:: vhdl

  receive(net, actor, request_msg);
  msg_type := message_type(request_msg);

  if msg_type = wait_until_idle_msg then
    reply_msg := new_msg;
    reply(net, request_msg, reply_msg);
  elsif msg_type = write_msg then

    ...

  else
    unexpected_msg_type(msg_type);
  end if;

Note that no information is pushed to the reply message in this example but you may want to have a message type for
debugging purposes.

************************************************************
Message Handlers and Verification Component Interfaces (VCI)
************************************************************

The synchronization based on ``wait_until_idle_msg`` is something that can be used by many actors. We've seen before
how we can create transaction procedures like ``read`` and ``write`` and we can also create such a procedure for this
message. To synchronize with the memory BFM actor we would just do

.. code-block:: vhdl

  wait_until_idle(net, memory_bfm_pkg.actor);

We can also create a reusable procedure for the message handling.

.. code-block:: vhdl

  procedure handle_wait_until_idle(
    signal net : inout event_t;
    variable msg_type : inout msg_type_t;
    variable request_msg : inout msg_t) is
    variable reply_msg : msg_t;
  begin
    if msg_type = wait_until_idle_msg then
      handle_message(msg_type);
      reply_msg := new_msg;
      reply(net, request_msg, reply_msg);
    end if;
  end;

This is the same code I showed before to handle the wait until idle message with one addition - the call to the
``handle_message`` procedure. ``handle_message`` is in itself a message handler, the simplest message handler possible.
The only thing it does is to set ``msg_type`` to a special value ``message_handled``. To understand why we can look at
the updated BFM.

.. code-block:: vhdl

  receive(net, actor, request_msg);
  msg_type := message_type(request_msg);

  handle_wait_until_idle(net, msg_type, request_msg);

  if msg_type = write_msg then

    ...

  else
    unexpected_msg_type(msg_type);
  end if;

After ``handle_wait_until_idle`` returns, ``msg_type`` has the value ``message_handled`` and no more message handling
takes place in the following if statement. The ``unexpected_msg_type`` procedure of the else branch will be called but
that procedure takes no action when the message type is ``message_handled``.

By putting the ``wait_until_idle_msg`` message type and the ``wait_until_idle`` and ``handle_wait_until_idle``
procedures in a package we can create a reusable verification component interface (VCI) that can be added to actors.
An actor can call several message handlers, that is add several interfaces, and you can create message handlers that
call other message handlers to bundle interfaces. The interface I just presented is actually already provided as a part
of VUnit's :ref:`synchronization VCI <sync_vci>`.

Timeout
-------

Receive and send procedures which may block on empty or full inboxes have an optional timeout parameter. For example

.. code-block:: vhdl

  receive(net, actor, msg, timeout => 10 ns);

Reaching the timeout limit is an error that will fail the testbench. If you need to timeout a receive call without
failing you can use the ``wait_for_message``, ``has_message``, and ``get_message`` subprograms. The ``status`` returned
by the ``wait_for_message`` procedure below will be ``ok`` if a message is received before the timeout and ``timeout``
if the timeout limit is reached.

.. code-block:: vhdl

  wait_for_message(net, my_actor, status, timeout => 10 ns);

You can also see if an actor has at least one message in its inbox.

.. code-block:: vhdl

  has_message(my_actor);

When there are messages in the inbox you can get the oldest with

.. code-block:: vhdl

  get_message(net, my_actor, msg);

It's also possible to wait for a reply with a timeout.

.. code-block:: vhdl

  wait_for_reply(net, request_msg, status, timeout => 10 ns);
  if status = ok then
    get_reply(net, request_msg, reply_msg);
  end if;


Deferred Actor Creation
-----------------------

When finding an actor using the ``find`` function there is a potential race condition. What if the actor hasn't been
created yet? The default VUnit solution is that the ``find`` function creates a temporary actor with limited
functionality and defer proper actor creation until the ``new_actor`` function is called. The process calling ``find``
can send messages to this actor and can't tell the difference. However, it's not possible to call receive type of
procedures on such an actor. Full actor capabilities are acquired when the receiver process has created the actor with
``new_actor``.

The danger with this approach is if the actor "found" by the sender is never created, maybe as a result of a misspelled
name. In that case the sender will send messages that are never received but it will block on the second send since the
temporary actor has an inbox of size one. The safest way to avoid this is to not use ``find`` but rather make the actor
constant available to the sender. It's also possible to to disable the deferred creation by adding an extra parameter
to the ``find`` call

.. code-block:: vhdl

  find("actor name", enable_deferred_creation => false);

If the actor isn't found the function returns ``null_actor`` so to make this work you must make sure that the
``find`` function is called after ``new_actor``, for example by adding an initial delay before making the call.

Another approach is to make sure that there are no deferred creations pending a short delay into the simulation, before
the actual testing starts. You can find out by calling the ``num_of_deferred_creations`` function.

.. _publisher_subscriber:

****************************
Publisher/Subscriber Pattern
****************************

A common message pattern is the publisher/subscriber pattern where a publisher actor publishes a message rather than
sending it. Actors interested in these messages subscribe to the publisher and the published messages are received just
like messages sent directly to the subscribers. The purpose of this pattern is to decouple the publisher from the
subscribers, it doesn't have to know who the subscribers are and there is no need to update the publisher when
subscribers are added or removed.

An example for how this pattern can be used is when you have a verification component monitoring an interface of the
DUT. Let's say we have a simple adder with streaming input and output interfaces. The input interface consists of two
unsigned operands and a data valid signal while the output consists of an unsigned ``sum`` and a data valid. The input
interface is controlled by a driver BFM which receives ``add`` transactions as well as ``wait_for_time`` to insert idle
cycles in the input stream. ``wait_for_time`` is a standard VCI provided by the :ref:`sync_pkg <sync_vci>`. The output
interface has a monitor process which creates sum messages from valid output sums. Just like the input driver doesn't
know or care who's sending the add transactions, the monitor doesn't have to know who's consuming the sum messages. To
achieve that it will publish the sum messages and just provide the publishing actor (``monitor``).

.. code-block:: vhdl

 monitor_process : process is
   variable msg : msg_t;
 begin
   wait until rising_edge(clk) and (dv_out = '1');
   msg := new_msg(sum_msg);
   push(msg, to_integer(sum));
   publish(net, monitor, msg);
 end process;

In addition to the driver and the monitor there is a scoreboard process to verify the adder functionality. The
scoreboard subscribes to the sum messages published by the monitor using the ``subscribe`` procedure. Rather than
having a single actor the scoreboard has several actors called channels and the ``slave_channel`` is setup to subscribe
to messages published by the ``monitor`` actor.

.. code-block:: vhdl

 subscribe(slave_channel, monitor);

The next step is to make sure that the scoreboard also receives the add transactions on the input interface. There are
several ways to do this. One is to build another monitor for the input interface and another is to let the driver
publish the add transactions. However, in order to demonstrate ``com`` functionality this scoreboard will use a third
approach and let the scoreboard subscribe to inbound traffic to the driver. This can be done by adding a third
parameter to the ``subscribe`` call.

.. code-block:: vhdl

 subscribe(master_channel, driver, inbound);

The default value used before is ``published`` and it is also possible to subscribe to ``outbound`` traffic.
``outbound`` traffic is every output message from an actor regardless if that message is the result of a ``publish``,
``send``, or ``reply`` call.

With the two subscriptions at hand we can create a scoreboard process. The main flow of the code below is to wait for
an ``add_msg`` on the ``master_channel`` (``wait_for_time`` is ignored) and when it's received wait for the associated
``sum_msg`` on the ``slave_channel``. Once both these messages are available the scoreboard will use its reference
model to verify that the output data matches the input.

.. code-block:: vhdl

  scoreboard_process : process is
    variable master_msg, slave_msg : msg_t;
    variable msg_type         : msg_type_t;

    procedure do_model_check(indata, outdata : msg_t) is
      variable op_a, op_b, sum : natural;
    begin
      op_a := pop(indata);
      op_b := pop(indata);
      sum  := pop(outdata);
      check_equal(sum, op_a + op_b);
    end;
  begin
    subscribe(master_channel, driver, inbound);
    subscribe(slave_channel, monitor);
    loop
      receive(net, master_channel, master_msg);
      msg_type := message_type(master_msg);

      handle_wait_until_idle(net, msg_type, master_msg);

      if msg_type = add_msg then
        receive(net, slave_channel, slave_msg);

        if message_type(slave_msg) = sum_msg then
          do_model_check(master_msg, slave_msg);
        end if;
      end if;
    end loop;
  end process;

In order for the test sequencer to know when the verification is complete it will send a ``wait_for_idle`` transaction
after all add transactions. That transaction is handled by the ``handle_wait_until_idle`` message handler on the
scoreboard side. The example test sequencer below just sends 10 random add messages separated by a random delay
(not good for functional coverage but good enough for this example).

.. code-block:: vhdl

        for i in 1 to 10 loop
          msg := new_msg(add_msg);
          push(msg, rnd.RandInt(0, 255));
          push(msg, rnd.RandInt(0, 255));
          send(net, driver, msg);
          wait_for_time(net, driver, rnd.RandTime(0 ns, 10 * clk_period));
        end loop;
        wait_until_idle(net, master_channel);

Subscribing to messages actively being published is the classic form of the publisher/subscriber communication pattern
while subscriptions on inbound or outbound traffic is more like eavesdropping. This has implications that you need to
be aware of:

* When receiving a message that has been published, a call to
  ``sender`` or ``receiver`` on that message will return the publisher
  and subscriber actors respectively. However, when receiving a
  message resulting from an inbound or outbound subscription the two
  functions will return the sender and the receiver for the original
  message transaction.

* The subscriber of inbound and outbound traffic will receive all
  messages, not only those that would have been published if the
  decision was more active. For example, if someone sends a
  ``wait_for_idle`` transaction to the driver it will also be sent to
  the subscriber which will act upon it "thinking" it was from the
  test sequencer. This wouldn't be a problem if we had a monitor for
  the input interface only publishing add messages. It's still
  possible to fix though, for example by only handling
  ``wait_for_idle`` transactions aimed at the master channel.

.. code-block:: vhdl

      if receiver(master_msg) = master_channel then
        handle_wait_until_idle(net, msg_type, master_msg);
      end if;

* Since you can subscribe on inbound traffic you can also subscribe to
  the inbound traffic of a subscriber. This may not have great
  practical value but can, if misused, create an infinite loop of
  subscriptions which will hang the simulation.

* A subscription on the outbound traffic of an actor won't pick up messages sent anonymously.
* A subscription on the inbound traffic of an actor won't pick up replies to an anonymously request.

Blocking subscribers
--------------------

Although the intent of the publisher/subscriber pattern is to decouple the publisher from the subscribers it can still
be affected if a subscriber inbox is full. A message transaction will be blocked until all of its subscribers and any
regular receiver have available space in their inboxes.

Unsubscribing
-------------

An actor can unsubscribe from a subscription at any time by calling ``unsubscribe`` with the same parameters used when
calling the ``subscribe`` procedure.

*********
Debugging
*********
Message passing provides a communication mechanism an abstraction level above the normal signalling in VHDL.
This also means that there is a need for an equally elevated level of debugging. To support that ``com`` has
a number of built-in features specially targeting debugging.

Logging Messages
----------------

One way of debugging is to inspect the messages that flow through the system, for example by subscribing to actor
traffic. You can use previously presented functions to find out sender, receiver and message content but you can
also convert a message to a string such that it can be logged.

.. code-block:: vhdl

  to_string(reply_msg)

The resulting string may look something like this

.. code-block:: console

  3:2 memory BFM -> test sequencer (read reply)

The first number (``3``) is the message ID which is unique to this message. The second number (``2``) is present
in reply messages and denotes the message ID for the request message. After that we have the sender
(``memory BFM``) which sent the message to (``->``) the receiver (``test sequencer``). Finally, the value in
parentheses (``read reply``) is the message type. All communicated messages have a message ID but not all messages
are replies, sender and receivers may be anonymous and not all messages have a message type. Fields missing a
value will be replaced with ``-``.

Note that ``com`` has limited knowledge of the contents of a message. All data pushed into a message is encoded
and is basically handled as a sequence of bytes without any overhead for type information. ``com`` doesn't
know if four bytes represents an integer, four characters or something else. The interpretation of
these bytes takes place when the user pops data using a type specific pop function. The exception is the message
type for which the type overhead is included to provide better debugging. Higher levels of debug information,
for example that a message represents a read request to a specific address is something that the verification
component using ``com`` provides.

Trace Log
---------

Rather than manually logging messages you can quickly see all messages by showing the trace logs. ``com`` provides
a logger, ``com_logger``, and you enable the trace logs by showing log entries on the ``trace`` log level.

.. code-block:: vhdl

  show(com_logger, display_handler, trace);

Ignoring the initial part introduced by the logging framework (everything up to and including ``TRACE -``) we
still see a difference when compared to the string presented above.

.. code-block:: console

  30000 ps - vunit_lib:com -   TRACE - test sequencer inbox => [3:2 memory BFM -> test sequencer (read reply)]

First is an actor mailbox (``test sequencer inbox``), then an arrow (``=>``) followed by the message string
enclosed in square brackets. This means that the message was removed from the mailbox, for example as a result
of a ``receive_reply`` call. ``com`` also logs when a message is put into a mailbox. In this
example that event is logged 10 ns earlier and is the result of a ``reply`` call

.. code-block:: console

  20000 ps - vunit_lib:com -   TRACE - [3:2 memory BFM -> test sequencer (read reply)] => test sequencer inbox

Now that we have all these transactions available it becomes possible to follow sequences of events. For example,
at time 0 ps we have the message with ID = 2 which is the request message for the reply above.

.. code-block:: console

  0 ps - vunit_lib:com -   TRACE - [2:- test sequencer -> memory BFM (read)] => memory BFM inbox

Again, if you want higher level of debug information you can add debug logging to your BFM which may
result in something like this.

.. code-block:: console

      0 ps - vunit_lib:com -   TRACE - [2:- test sequencer -> memory BFM (read)] => memory BFM inbox
  10000 ps - vunit_lib:com -   TRACE - memory BFM inbox => [2:- test sequencer -> memory BFM (read)]
  20000 ps - memory BFM    -   DEBUG - Reading x"21" from address x"80"
  20000 ps - vunit_lib:com -   TRACE - [3:2 memory BFM -> test sequencer (read reply)] => test sequencer inbox
  30000 ps - vunit_lib:com -   TRACE - test sequencer inbox => [3:2 memory BFM -> test sequencer (read reply)]

State Information
-----------------

In addition to tracing messages you can also examine the state of the communication system. By calling
``get_mailbox_state`` you can take a snapshot and examine all messages in an actor mailbox.

.. code-block:: vhdl

  mailbox_state := get_mailbox_state(memory_bfm_pkg.actor, inbox);

``mailbox_state`` is a record that you can expand and examine in your simulator. Be aware that this gives you a
glimpse of internal representations of data which we may change. It's suitable for browsing but not something you
should act upon programmatically.

You can also create a string representation of the mailbox state by calling

.. code-block:: vhdl

  get_mailbox_state_string(memory_bfm_pkg.actor, inbox)

The result is something like this

.. code-block:: console

  Mailbox: inbox
    Size: 2147483647
    Messages:
      0. 5:- _actor_3 -> memory BFM (write)
      1. 6:- _actor_3 -> memory BFM (read)

The size is the maximum number of messages that the mailbox can contain (this is dynamically allocated) while the
list at the bottom shows the actual messages in the mailbox. Message 0 is the oldest message and the first one
to be returned when you call ``receive``.

You can also get an actor's state as well as the string representation for that state

.. code-block:: vhdl

  actor_state := get_actor_state(driver);
  debug(get_actor_state_string(driver));

The string representation contains information about both mailboxes, subscriptions and subscribers and if the
actor's creation is deferred. For example,

.. code-block:: console

  Name: driver
    Is deferred: no
    Mailbox: inbox
      Size: 2147483647
      Messages:
        0. 8:- _actor_3 -> driver (add)
        1. 9:- _actor_3 -> driver (add)
        2. 10:- _actor_3 -> driver (add)
    Mailbox: outbox
      Size: 2147483647
      Messages:
    Subscriptions:
    Subscribers:
      driver channel subscribes to inbound traffic

In this case the outbox is empty and `driver` doesn't subscribe to anything. However, the ``driver channel``
actor subscribes to inbound traffic to ``driver``.

Finally, you can get the state for the messenger which is the manager of the communication system. That state
contains two lists - one with the states of all active actors (those not deferred) and one with the states of
all deferred actors.

.. code-block:: vhdl

  messenger_state := get_messenger_state;
  debug(get_messenger_state_string);

***************
Deprecated APIs
***************

``com`` maintains a number of deprecated APIs for better backward compatibility. Using these APIs will result in
a runtime error unless enabled by calling the ``allow_deprecated`` procedure.

Earlier releases of ``com`` would not cause a runtime error on timeout. This behavior can be enabled with the
deprecated APIs by calling ``allow_timeout``. If not, a timeout will result in an error with the exception of the
``wait_for_messages`` and ``wait_for_reply`` procedures which return a status.

The deprecated APIs will be removed in the future so it's recommended to replace these with contemporary APIs.
