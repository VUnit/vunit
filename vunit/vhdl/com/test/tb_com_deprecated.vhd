-- Test suite for deprecated parts of the com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

entity tb_com_deprecated is
  generic (
    runner_cfg : string);
end entity tb_com_deprecated;

architecture test_fixture of tb_com_deprecated is
  signal hello_world_received, start_receiver, start_server,
    start_server2, start_server3, start_server5,
    start_subscribers : boolean := false;
  signal start_limited_inbox, start_limited_inbox_subscriber,
    limited_inbox_actor_done : boolean                  := false;
  signal hello_subscriber_received                     : std_logic_vector(1 to 2) := "ZZ";

  constant com_logger : logger_t := get_logger("vunit_lib:com");
begin
  test_runner : process
    variable actor_to_destroy, actor_to_keep, actor, actor2, self,
      receiver, server, deferred_actor, publisher, subscriber : actor_t;
    variable status                      : com_status_t;
    variable receipt, receipt2 : receipt_t;
    variable n_actors                    : natural;
    variable message                     : message_ptr_t;
    variable reply_message               : message_ptr_t;
    variable request_message             : message_ptr_t;
    variable t_start, t_stop             : time;
    variable ack                         : boolean;
  begin
    test_runner_setup(runner, runner_cfg);
    allow_timeout;
    allow_deprecated;

    while test_suite loop
      reset_messenger;
      self := create("test runner");
      if run("Test that a created actor can be destroyed") then
        actor_to_destroy := create("actor to destroy");
        actor_to_keep    := create("actor to keep");
        n_actors         := num_of_actors;
        destroy(actor_to_destroy, status);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(status = ok, "Expected destroy status to be ok");
        check(actor_to_destroy = null_actor_c, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor_c, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor_c,
              "Actors other than the one destroyed must not be affected");
      elsif run("Test that a non-existing actor cannot be destroyed") then
        actor := null_actor_c;
        mock(com_logger);
        destroy(actor, status);
        check_only_log(com_logger, "UNKNOWN ACTOR ERROR.", failure);
        unmock(com_logger);
      elsif run("Test that a created actor get the correct inbox size") then
        actor  := new_actor("actor with max inbox");
        check(inbox_size(actor) = positive'high, "Expected maximum sized inbox");
        actor2 := new_actor("actor with bounded inbox", 23);
        check(inbox_size(actor2) = 23, "Expected inbox size = 23");
        check(inbox_size(null_actor_c) = 0, "Expected no inbox on null actor");
        check(inbox_size(find("actor to be created")) = 1,
              "Expected inbox size on actor with deferred creation to be one");
        check(inbox_size(new_actor("actor to be created", 42)) = 42,
              "Expected inbox size on actor with deferred creation to change to given value when created");
      elsif run("Test that a message can be deleted") then
        message := compose("hello");
        delete(message);
        check(message = null, "Message not deleted");
      elsif run("Test that an actor can send a message to another actor") then
        start_receiver <= true;
        wait for 1 ns;
        receiver       := find("receiver");
        message        := compose("hello world", self);
        send(net, receiver, message);
        check(message.sender = self);
        check(message.receiver = receiver);
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");
      elsif run("Test that an actor can send a message in response to another message from an a priori unknown actor") then
        start_server <= true;
        wait for 1 ns;
        server       := find("server");
        message      := compose("request", self);
        send(net, server, message, receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message);
        if check(message.status = ok, "Expected no receive problems") then
          check(message.payload.all = "request acknowledge", "Expected ""request acknowledge""");
        end if;
        delete(message);
      elsif run("Test that an actor can send a message to itself") then
        send(net, self, "hello", receipt);
        receive(net, self, message);
        check(message.status = ok, "Expected no receive problems");
        check_equal(message.payload.all, "hello");
      elsif run("Test that an actor can poll for incoming messages") then
        receive(net, self, message, 0 ns);
        check(message.payload = null, "Expected no message payload");
        check(message.status = timeout, "Expected timeout");
        send(net, self, self, "hello again", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message, 0 ns);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello again", "Expected ""hello again""");
          check(message.sender = self, "Expected message from myself");
        end if;
        delete(message);
      elsif run("Test that an actor can send to an actor with deferred creation") then
        deferred_actor := find("deferred actor");
        send(net, deferred_actor, "hello actor to be created", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        deferred_actor := create("deferred actor");
        receive(net, deferred_actor, message);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello actor to be created", "Expected ""hello actor to be created""");
        end if;
        delete(message);
      elsif run("Test that empty messages can be sent") then
        send(net, self, "", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "", "Expected an empty message");
        end if;
        delete(message);
      elsif run("Test that each sent message gets an increasing message number") then
        send(net, self, "", receipt);
        check(receipt.id = 1, "Expected first receipt id to be 1");
        send(net, self, "", receipt);
        check(receipt.id = 2, "Expected second receipt id to be 2");
        receive(net, self, message);
        check(message.id = 1, "Expected first message id to be 1");
        receive(net, self, message);
        check(message.id = 2, "Expected second message id to be 2");
      elsif run("Test that a limited-inbox receiver can receive as expected without blocking") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        t_start             := now;
        send(net, self, actor, "First message", receipt);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on first message");
        t_start             := now;
        send(net, self, actor, "Second message", receipt, 0 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on second message");
        t_start             := now;
        send(net, actor, "Third message", receipt, 11 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 10 ns, "Expected a 10 ns blocking period on third message");
      elsif run("Test that sending to a limited-inbox receiver times out as expected") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        send(net, actor, "First message", receipt);
        send(net, actor, "Second message", receipt, 0 ns);
        mock(com_logger);
        send(net, actor, "Third message", receipt, 9 ns);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_only_log(com_logger, "FULL INBOX ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that an actor can publish messages to multiple subscribers") then
        publisher         := create("publisher");
        start_subscribers <= true;
        wait for 1 ns;
        publish(net, publisher, "hello subscriber", status);
        check(status = ok, "Expected publish to succeed");
        wait until hello_subscriber_received = "11" for 1 ns;
        check(hello_subscriber_received = "11", "Expected ""hello subscribers"" to be received at the subscribers");

      elsif run("Test that a subscriber can unsubscribe") then
        subscribe(self, self, status);
        check(status = ok, "Expected subscription to be ok");
        publish(net, self, "hello subscriber", status);
        check(status = ok, "Expected publish to succeed");
        receive(net, self, message, 0 ns);
        check(message.status = ok, "Expected no problems with receive");
        check(message.payload.all = "hello subscriber", "Expected a ""hello subscriber"" message");
        unsubscribe(self, self, status);
        publish(net, self, "hello subscriber", status);
        check(status = ok, "Expected publish to succeed");
        receive(net, self, message, 0 ns);
        check(message.status = timeout, "Expected no message");
      elsif run("Test that a destroyed subscriber is not addressed by the publisher") then
        subscriber := create("subscriber");
        subscribe(subscriber, self, status);
        check(status = ok, "Expected subscription to be ok");
        publish(net, self, "hello subscriber", status);
        check(status = ok, "Expected publish to succeed");
        receive(net, subscriber, message, 0 ns);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello subscriber", "Expected a ""hello subscriber"" message");
        end if;
        destroy(subscriber, status);
        check(status = ok, "Expected destroy status to be ok");
        publish(net, self, "hello subscriber", status);
        check(status = ok, "Expected publish to succeed. Got " & com_status_t'image(status) & ".");
      elsif run("Test that an actor can only subscribe once to the same publisher") then
        subscribe(self, self, status);
        check(status = ok, "Expected subscription to be ok");
        mock(com_logger);
        subscribe(self, self, status);
        check_only_log(com_logger, "ALREADY A SUBSCRIBER ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that a client can wait for an out-of-order request reply") then
        start_server2 <= true;
        server        := find("server2");
        send(net, self, server, "request1", receipt);
        send(net, self, server, "request2", receipt2);

        receive_reply(net, self, receipt2.id, reply_message);
        check(reply_message.payload.all = "reply2", "Expected ""reply2""");
        check(reply_message.request_id = receipt2.id, "Expected request_id = " & integer'image(receipt2.id) &
              " but got " & integer'image(reply_message.request_id));
        receive_reply(net, self, receipt.id, reply_message);
        check(reply_message.payload.all = "reply1", "Expected ""reply1""");
        check(reply_message.request_id = receipt.id, "Expected request_id = " & integer'image(receipt.id) &
              " but got " & integer'image(reply_message.request_id));
        delete(reply_message);
      elsif run("Test that a synchronous request can be made") then
        start_server3 <= true;
        server        := find("server3");

        request(net, self, server, "request1", reply_message);
        check(reply_message.payload.all = "reply1", "Expected ""reply1""");
        delete(reply_message);

        request(net, self, server, "request2", ack, status);
        check(status = ok, "Expected request to succeed");
        check(ack, "Expected positive acknowledgement");

        request(net, self, server, "request3", ack, status);
        check(status = ok, "Expected request to succeed");
        check(not ack, "Expected negative acknowledgement");

        t_start := now;
        request(net, self, server, "request4", reply_message, 3 ns);
        check(reply_message.status = timeout, "Expected timeout");
        check(now - t_start = 3 ns, "Expected timeout after 3 ns");
        delete(reply_message);

        send(net, self, server, "A message", receipt);
        send(net, self, server, "This will sit in the inbox for 3 ns", receipt);
        t_start := now;
        request(net, self, server,
                "The send part will block for 3 ns, the receive part should timout after 2 to get a total of 5 ns",
                reply_message, 5 ns);
        check(reply_message.status = timeout, "Expected timeout");
        check(now - t_start = 5 ns, "Expected timeout after 5 ns");
        delete(reply_message);
      elsif run("Test that an anonymous request can be made") then
        start_server5 <= true;
        server := find("server5");

        request_message := compose("request");
        send(net, server, request_message);
        wait for 10 ns;
        receive_reply(net, request_message, reply_message);
        check_equal(reply_message.payload.all, "reply");

        request_message := compose("request2");
        send(net, server, request_message);
        receive_reply(net, request_message, reply_message);
        check_equal(reply_message.payload.all, "reply2");

        request_message := compose("request3");
        request(net, server, request_message, reply_message);
        check_equal(reply_message.payload.all, "reply3");
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);

  receiver : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
    variable status  : com_status_t;
  begin
    wait until start_receiver;
    self    := create("receiver");
    wait_for_messages(net, self, status);
    message := get_message(self);
    if check(message.payload.all = "hello world", "Expected ""hello world""") then
      hello_world_received <= true;
    end if;
    delete(message);
    wait;
  end process receiver;

  server : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
    variable receipt : receipt_t;
  begin
    wait until start_server;
    self := create("server");
    receive(net, self, message);
    if check(message.payload.all = "request", "Expected ""request""") then
      send(net, message.sender, "request acknowledge", receipt);
      check(receipt.status = ok, "Expected send to succeed");
    end if;
    delete(message);
    wait;
  end process server;

  subscribers : for i in 1 to 2 generate
    process is
      variable self, publisher : actor_t;
      variable message         : message_ptr_t;
      variable status          : com_status_t;
    begin
      wait until start_subscribers;
      self      := create("subscriber " & integer'image(i));
      publisher := find("publisher");
      subscribe(self, publisher, status);
      receive(net, self, message);
      if check(message.payload.all = "hello subscriber", "Expected ""hello subscriber""") then
        hello_subscriber_received(i)     <= '1';
        hello_subscriber_received(3 - i) <= 'Z';
      end if;
      delete(message);
      wait;
    end process;
  end generate subscribers;

  server2 : process is
    variable self                               : actor_t;
    variable request_message1, request_message2 : message_ptr_t;
    variable receipt                            : receipt_t;
  begin
    wait until start_server2;
    self := create("server2");
    receive(net, self, request_message1);
    check(request_message1.payload.all = "request1", "Expected ""request1""");
    receive(net, self, request_message2);
    check(request_message2.payload.all = "request2", "Expected ""request2""");

    reply(net, request_message2.sender, request_message2.id, "reply2", receipt);
    check(receipt.status = ok, "Expected reply to succeed");
    reply(net, request_message1.sender, request_message1.id, "reply1", receipt);
    check(receipt.status = ok, "Expected reply to succeed");

    delete(request_message1);
    delete(request_message2);
    wait;
  end process server2;

  server3 : process is
    variable self            : actor_t;
    variable request_message : message_ptr_t;
    variable receipt         : receipt_t;
  begin
    wait until start_server3;
    self := create("server3", 1);

    receive(net, self, request_message);
    check(request_message.payload.all = "request1", "Expected ""request1""");
    reply(net, request_message.sender, request_message.id, "reply1", receipt);
    check(receipt.status = ok, "Expected reply to succeed");
    delete(request_message);

    receive(net, self, request_message);
    check(request_message.payload.all = "request2", "Expected ""request2""");
    acknowledge(net, request_message.sender, request_message.id, true, receipt);
    check(receipt.status = ok, "Expected acknowledge to succeed");
    delete(request_message);

    receive(net, self, request_message);
    acknowledge(net, request_message.sender, request_message.id, false, receipt);
    delete(request_message);

    receive(net, self, request_message);
    delete(request_message);

    receive(net, self, request_message);
    wait for 3 ns;
    receive(net, self, request_message);
    delete(request_message);
    wait;
  end process server3;

  server5 : process is
    variable self            : actor_t;
    variable request_message : message_ptr_t;
    variable reply_message : message_ptr_t;
  begin
    wait until start_server5;
    self := create("server5");

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request");
    reply_message := compose("reply");
    reply(net, request_message, reply_message);

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request2");
    reply_message := compose("reply2");
    wait for 10 ns;
    reply(net, request_message, reply_message);

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request3");
    reply_message := compose("reply3");
    reply(net, request_message, reply_message);

    wait;
  end process server5;

  limited_inbox_actor : process is
    variable self : actor_t;
    variable msg               : msg_t;
  begin
    wait until start_limited_inbox;
    self                     := create("limited inbox", 2);
    wait for 10 ns;
    receive(net, self, msg);
    receive(net, self, msg);
    receive(net, self, msg);
    limited_inbox_actor_done <= true;
    wait;
  end process limited_inbox_actor;

  limited_inbox_subscriber : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
  begin
    wait until start_limited_inbox_subscriber;
    self := create("limited inbox subscriber", 1);
    subscribe(self, find("test runner"));
    wait for 10 ns;
    receive(net, self, message);
    wait;
  end process limited_inbox_subscriber;


end test_fixture;
