-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

entity tb_com is
  generic (
    runner_cfg : string);
end entity tb_com;

architecture test_fixture of tb_com is
  signal hello_world_received, start_receiver, start_server,
    start_server2, start_server3, start_server4, start_server5, start_subscribers : boolean := false;
  signal hello_subscriber_received                     : std_logic_vector(1 to 2) := "ZZ";
  signal start_limited_inbox, limited_inbox_actor_done : boolean                  := false;
  signal start_limited_inbox_subscriber                : boolean                  := false;
begin
  test_runner : process
    variable self, actor, actor2, receiver, server, publisher, subscriber : actor_t;
    variable status                                                       : com_status_t;
    variable receipt, receipt2, receipt3                                  : receipt_t;
    variable n_actors                                                     : natural;
    variable t_start, t_stop                                              : time;
    variable ack                                                          : boolean;
    variable msg, msg2, request_msg, request_msg2, request_msg3, reply_msg : msg_t;
  begin
    checker_init(display_format => verbose,
                 file_name      => join(output_path(runner_cfg), "error.csv"),
                 file_format    => verbose_csv);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_messenger;
      self := create("test runner");

      -- Create
      if run("Test that named actors can be created") then
        n_actors := num_of_actors;
        actor := create("actor");
        check(actor /= null_actor_c, "Failed to create named actor");
        check_equal(name(actor), "actor");
        check_equal(num_of_actors, n_actors + 1, "Expected one extra actor");
        check(create("other actor").id /= create("another actor").id, "Failed to create unique actors");
        check_equal(num_of_actors, n_actors + 3, "Expected two extra actors");
      elsif run("Test that no name actors can be created") then
        actor := create;
        check(actor /= null_actor_c, "Failed to create no name actor");
        check_equal(name(actor), "");
      elsif run("Expected to fail: Test that two actors of the same name cannot be created") then
        actor := create("actor2");
        actor := create("actor2");
      elsif run("Test that multiple no-name actors can be created") then
        n_actors := num_of_actors;
        actor := create;
        actor2 := create;
        check(actor.id /= actor2.id, "The two actors must have different identities");
        check_equal(num_of_actors, n_actors + 2);
        check_equal(num_of_deferred_creations, 0);

      -- Find
      elsif run("Test that a created actor can be found") then
        actor := create("actor to be found");
        check(find("actor to be found", false) /= null_actor_c, "Failed to find created actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
      elsif run("Test that an actor not created is found and its creation is deferred") then
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        actor := find("actor with deferred creation");
        check(actor /= null_actor_c, "Failed to find actor with deferred creation");
        check_equal(num_of_deferred_creations, 1, "Expected one deferred creations");
      elsif run("Test that deferred creation can be suppressed when an actor is not found") then
        actor  := create("actor");
        actor2 := find("actor with deferred creation", false);
        check(actor2 = null_actor_c, "Didn't expect to find any actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
      elsif run("Test that a created actor get the correct inbox size") then
        actor  := create("actor with max inbox");
        check(inbox_size(actor) = positive'high, "Expected maximum sized inbox");
        actor2 := create("actor with bounded inbox", 23);
        check(inbox_size(actor2) = 23, "Expected inbox size = 23");
        check(inbox_size(null_actor_c) = 0, "Expected no inbox on null actor");
        check(inbox_size(find("actor to be created")) = 1,
              "Expected inbox size on actor with deferred creation to be one");
        check(inbox_size(create("actor to be created", 42)) = 42,
              "Expected inbox size on actor with deferred creation to change to given value when created");
      elsif run("Test that no-name actors can't be found") then
        actor := create;
        actor2 := create;
        check(find("") = null_actor_c, "Must not find a no-name actor");
        check_equal(num_of_deferred_creations, 0);

      -- Destroy
      elsif run("Test that a created actor can be destroyed") then
        actor    := create("actor to destroy");
        actor2   := create("actor to keep");
        n_actors := num_of_actors;
        destroy(actor);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(actor = null_actor_c, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor_c, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor_c,
              "Actors other than the one destroyed must not be affected");
      elsif run("Expected to fail: Test that a non-existing actor cannot be destroyed") then
        actor := null_actor_c;
        destroy(actor);
      elsif run("Test that all actors can be destroyed") then
        reset_messenger;
        actor  := create("actor to destroy");
        actor2 := create("actor to destroy 2");
        check(num_of_actors = 2, "Expected two actors");
        reset_messenger;
        check(num_of_actors = 0, "Failed to destroy all actors");

      -- Messages
      elsif run("Test that a message can be created") then
        msg := create;
        check_equal(msg.id, no_message_id_c);
        check(msg.status = ok);
        check(msg.sender = null_actor_c);
        check(msg.receiver = null_actor_c);
        check_equal(msg.request_id, no_message_id_c);
        check_equal(length(msg.data), 0);

        actor  := create("sender");
        msg2 := create(actor);
        check_equal(msg2.id, no_message_id_c);
        check(msg2.status = ok);
        check(msg2.sender = actor);
        check(msg2.receiver = null_actor_c);
        check_equal(msg2.request_id, no_message_id_c);
        check_equal(length(msg2.data), 0);
      elsif run("Test that a message can be deleted") then
        actor  := create("sender");

        msg := create(actor);
        msg.id := 1;
        msg.status := null_message_error;
        msg.receiver := actor;
        msg.request_id := 1;
        push(msg.data, 1);

        delete(msg);

        check_equal(msg.id, no_message_id_c);
        check(msg.status = ok);
        check(msg.sender = null_actor_c);
        check(msg.receiver = null_actor_c);
        check_equal(msg.request_id, no_message_id_c);
        check(msg.data = null_queue);

      -- Send and receive
      elsif run("Test that data ownership is lost at send") then
        msg := create;
        push_string(msg.data, "hello");
        send(net, self, msg);
        check(msg.data = null_queue);
      elsif run("Test that an actor can send a message to another actor") then
        start_receiver <= true;
        wait for 1 ns;
        receiver       := find("receiver");
        msg := create(self);
        push_string(msg.data, "hello world");
        send(net, receiver, msg);
        check(msg.sender = self);
        check(msg.receiver = receiver);
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");
      elsif run("Test that an actor can send a message in response to another message from an a priori unknown actor") then
        start_server <= true;
        wait for 1 ns;
        server       := find("server");
        request_msg := create(self);
        push_string(request_msg.data, "request");
        send(net, server, request_msg);
        receive(net, self, reply_msg);
        check(reply_msg.status = ok, "Expected no receive problems");
        check_equal(pop_string(reply_msg.data), "request acknowledge");
      elsif run("Test that an actor can send a message to itself") then
        msg := create;
        push_string(msg.data, "hello");
        send(net, self, msg);
        receive(net, self, msg2);
        check(msg2.status = ok, "Expected no receive problems");
        check_equal(pop_string(msg2.data), "hello");
      elsif run("Test that no-name actors can communicate") then
        actor    := create;
        msg := create;
        push_string(msg.data, "hello");
        send(net, actor, msg);
        receive(net, actor, msg2);
        check_equal(pop_string(msg2.data), "hello");
      elsif run("Test that an actor can poll for incoming messages") then
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected timeout");
        msg := create(self);
        push_string(msg.data, "hello again");
        send(net, self, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = ok, "Expected ok status");
        msg2 := get_message(self);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(pop_string(msg2.data), "hello again");
        check(msg2.sender = self, "Expected message from myself");
      elsif run("Expected to fail: Test that sending to a non-existing actor results in an error") then
        msg := create;
        push_string(msg.data, "hello");
        send(net, null_actor_c, msg);
      elsif run("Test that an actor can send to an actor with deferred creation") then
        actor := find("deferred actor");
        msg := create;
        push_string(msg.data, "hello actor to be created");
        send(net, actor, msg);
        actor := create("deferred actor");
        receive(net, actor, msg2);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(pop_string(msg2.data), "hello actor to be created");
      elsif run("Expected to fail: Test that receiving from an actor with deferred creation results in an error") then
        actor := find("deferred actor");
        receive(net, actor, msg);
      elsif run("Test that empty messages can be sent") then
        msg := create;
        send(net, self, msg);
        receive(net, self, msg2);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(length(msg2.data), 0);
      elsif run("Test that each sent message gets an increasing message number") then
        msg := create;
        send(net, self, msg);
        check(msg.id = 1, "Expected first receipt id to be 1");
        msg := create;
        send(net, self, msg);
        check(msg.id = 2, "Expected first receipt id to be 2");
        receive(net, self, msg2);
        check(msg2.id = 1, "Expected first message id to be 1");
        receive(net, self, msg2);
        check(msg2.id = 2, "Expected first message id to be 2");
      elsif run("Test that a limited-inbox receiver can receive as expected without blocking") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        t_start             := now;
        msg := create;
        push_string(msg.data , "First message");
        send(net, actor, msg);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on first message");
        t_start             := now;
        msg := create;
        push_string(msg.data , "Second message");
        send(net, actor, msg, 0 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on second message");
        t_start             := now;
        msg := create;
        push_string(msg.data , "Third message");
        send(net, actor, msg, 11 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 10 ns, "Expected a 10 ns blocking period on third message");

        wait until limited_inbox_actor_done;
      elsif run("Expected to fail: Test that sending to a limited-inbox receiver times out as expected") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        msg := create;
        push_string(msg.data , "First message");
        send(net, actor, msg);
        msg := create;
        push_string(msg.data , "Second message");
        send(net, actor, msg, 0 ns);
        msg := create;
        push_string(msg.data , "Third message");
        send(net, actor, msg, 9 ns);

      -- Publish, subscribe, and unsubscribe
      elsif run("Test that an actor can publish messages to multiple subscribers") then
        publisher         := create("publisher");
        start_subscribers <= true;
        wait for 1 ns;
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, publisher, msg);
        check(msg.sender = publisher);
        check(msg.receiver = null_actor_c);
        wait until hello_subscriber_received = "11" for 1 ns;
        check(hello_subscriber_received = "11", "Expected ""hello subscribers"" to be received at the subscribers");
      elsif run("Test that subscribers receive messages sent on outbound subscription") then
        publisher         := create("publisher");
        start_subscribers <= true;
        wait for 1 ns;
        msg := create(publisher);
        push_string(msg.data, "hello subscriber");
        send(net, self, msg);
        wait until hello_subscriber_received = "11" for 1 ns;
        check(hello_subscriber_received = "11", "Expected ""hello subscribers"" to be received at the subscribers");
      elsif run("Test that subscribers don't receive duplicate message") then
        publisher         := create("publisher");
        subscribe(self, publisher);

        msg := create(publisher);
        push_string(msg.data, "hello");
        send(net, self, msg);

        receive(net, self, msg2, 0 ns);
        check(msg2.receiver = self);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected only one message");
      elsif run("Test that actors don't get send messages on a publish subscription") then
        publisher         := create("publisher");
        subscribe(self, publisher);

        msg := create(publisher);
        push_string(msg.data, "hello");
        send(net, publisher, msg);

        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");
      elsif run("Test that actors can subscribe to inbound traffic") then
        receiver := create;
        subscribe(self, receiver, inbound);
        msg := create;
        push_string(msg.data, "hello");
        send(net, receiver, msg);
        receive(net, receiver, msg2, 0 ns);
        receive(net, self, msg2, 0 ns);
        check_equal(pop_string(msg2.data), "hello");
        msg := create;
        push_string(msg.data, "publication");
        publish(net, receiver, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");
        actor := create("actor");
        msg := create(receiver);
        push_string(msg.data, "hello");
        send(net, actor, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");
      elsif run("Test that a subscriber can unsubscribe") then
        subscribe(self, self, published);
        subscribe(self, self, inbound);
        unsubscribe(self, self, inbound);
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg);
        receive(net, self, msg, 0 ns);
        check_equal(pop_string(msg.data), "hello subscriber");
        unsubscribe(self, self, published);
        publish(net, self, "hello subscriber");
        push_string(msg.data, "hello subscriber");
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");
      elsif run("Test that a destroyed subscriber is not addressed by the publisher") then
        subscriber := create("subscriber");
        subscribe(subscriber, self);
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg);
        receive(net, subscriber, msg, 0 ns);
        check_equal(pop_string(msg.data), "hello subscriber");
        destroy(subscriber);
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg);
      elsif run("Expected to fail: Test that an actor can only subscribe once to the same publisher") then
        subscribe(self, self);
        subscribe(self, self);
      elsif run("Expected to fail: Test that publishing to subscribers with full inboxes results is an error") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg);
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg, 8 ns);
      elsif run("Test that publishing to subscribers with full inboxes results passes if waiting") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg);
        msg := create;
        push_string(msg.data, "hello subscriber");
        publish(net, self, msg, 11 ns);

      -- Request, (receive_)reply and acknowledge
      elsif run("Test that a client can wait for an out-of-order request reply") then
        start_server2 <= true;
        server        := find("server2");

        request_msg := create(self);
        push_string(request_msg.data, "request1");
        send(net, server, request_msg);
        request_msg2 := create(self);
        push_string(request_msg2.data, "request2");
        send(net, server, request_msg2);
        request_msg3 := create(self);
        push_string(request_msg3.data, "request3");
        send(net, server, request_msg3);

        receive_reply(net, request_msg2, reply_msg);
        check(reply_msg.sender = server);
        check(reply_msg.receiver = self);
        check_equal(pop_string(reply_msg.data), "reply2");
        check_equal(reply_msg.request_id, request_msg2.id);

        receive_reply(net, request_msg, ack);
        check_false(ack, "Expected negative acknowledgement");

        receive_reply(net, request_msg3, ack);
        check(ack, "Expected positive acknowledgement");
      elsif run("Test that a synchronous request can be made") then
        start_server3 <= true;
        server        := find("server3");

        request_msg := create(self);
        push_string(request_msg.data, "request1");
        request(net, server, request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply1");

        request_msg := create(self);
        push_string(request_msg.data, "request2");
        request(net, server, request_msg, ack);
        check(ack, "Expected positive acknowledgement");

        request_msg := create(self);
        push_string(request_msg.data, "request3");
        request(net, server, request_msg, ack);
        check_false(ack, "Expected negative acknowledgement");
      elsif run("Test that waiting and getting a reply with timeout works") then
        start_server4 <= true;
        server        := find("server4");

        t_start := now;
        request_msg := create(self);
        push_string(request_msg.data, "request1");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        t_start         := now;
        request_msg := create;
        push_string(request_msg.data, "request2");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        request_msg := create(self);
        push_string(request_msg.data, "request3");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status);
        get_reply(request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply3");

        t_start         := now;
        request_msg := create;
        push_string(request_msg.data, "request4");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status);
        get_reply(request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply4");
      elsif run("Test that an anonymous request can be made") then
        start_server5 <= true;
        server := find("server5");

        request_msg := create;
        push_string(request_msg.data, "request");
        send(net, server, request_msg);
        wait for 10 ns;
        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply");

        request_msg := create;
        push_string(request_msg.data, "request2");
        send(net, server, request_msg);
        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply2");

        request_msg := create;
        push_string(request_msg.data, "request3");
        send(net, server, request_msg);
        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg.data), "reply3");

      -- Timeout
      elsif run("Expected to fail: Test that timeout on receive leads to an error") then
        receive(net, self, msg, 1 ns);

      -- Deprecated APIs
      elsif run("Expected to fail: Test that use of deprecated API leads to an error") then
        publish(net, self, "hello world", status);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);

  receiver : process is
    variable self    : actor_t;
    variable msg : msg_t;
    variable status  : com_status_t;
  begin
    wait until start_receiver;
    self                 := create("receiver");
    receive(net, self, msg);
    check(msg.sender = find("test runner"));
    check(msg.receiver = self);
    hello_world_received <= check_equal(pop_string(msg.data), "hello world");
    wait;
  end process receiver;

  server : process is
    variable self    : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server;
    self := create("server");
    receive(net, self, request_msg);
    if check_equal(pop_string(request_msg.data), "request") then
      reply_msg := create;
      push_string(reply_msg.data, "request acknowledge");
      send(net, request_msg.sender, reply_msg);
    end if;
    wait;
  end process server;

  subscribers : for i in 1 to 2 generate
    process is
      variable self, publisher : actor_t;
      variable msg         : msg_t;
    begin
      wait until start_subscribers;
      self      := create("subscriber " & integer'image(i));
      publisher := find("publisher");
      subscribe(self, publisher, outbound);
      receive(net, self, msg);
      if check_equal(pop_string(msg.data), "hello subscriber") then
        hello_subscriber_received(i)     <= '1';
        hello_subscriber_received(3 - i) <= 'Z';
      end if;
      wait;
    end process;
  end generate subscribers;

  server2 : process is
    variable self                                    : actor_t;
    variable request_msg1, request_msg2, request_msg3 : msg_t;
    variable reply_msg                                        : msg_t;
  begin
    wait until start_server2;
    self := create("server2");
    receive(net, self, request_msg1);
    check_equal(pop_string(request_msg1.data), "request1");
    receive(net, self, request_msg2);
    check_equal(pop_string(request_msg2.data), "request2");
    receive(net, self, request_msg3);
    check_equal(pop_string(request_msg3.data), "request3");

    reply_msg := create;
    push_string(reply_msg.data, "reply2");
    reply(net, request_msg2, reply_msg);
    check(reply_msg.sender = self);
    check(reply_msg.receiver = find("test runner"));
    acknowledge(net, request_msg3, true);
    acknowledge(net, request_msg1, false);
    wait;
  end process server2;

  server3 : process is
    variable self            : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server3;
    self := create("server3");

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request1");
    reply_msg := create;
    push_string(reply_msg.data, "reply1");
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request2");
    acknowledge(net, request_msg, true);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request3");
    acknowledge(net, request_msg, false);

    wait;
  end process server3;

  server4 : process is
    variable self            : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server4;
    self := create("server4", 1);

    receive(net, self, request_msg);
    receive(net, self, request_msg);
    receive(net, self, request_msg);
    reply_msg := create;
    push_string(reply_msg.data, "reply3");
    reply(net, request_msg, reply_msg);
    receive(net, self, request_msg);
    reply_msg := create;
    push_string(reply_msg.data, "reply4");
    reply(net, request_msg, reply_msg);
    wait;
  end process server4;

  server5 : process is
    variable self            : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server5;
    self := create("server5");

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request");
    reply_msg := create;
    push_string(reply_msg.data, "reply");
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request2");
    reply_msg := create;
    push_string(reply_msg.data, "reply2");
    wait for 10 ns;
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg.data), "request3");
    reply_msg := create;
    push_string(reply_msg.data, "reply3");
    reply(net, request_msg, reply_msg);

    wait;
  end process server5;

  limited_inbox_actor : process is
    variable self, test_runner : actor_t;
    variable msg           : msg_t;
    variable status            : com_status_t;
  begin
    wait until start_limited_inbox;
    self                     := create("limited inbox", 2);
    test_runner              := find("test runner");
    wait for 10 ns;
    receive(net, self, msg);
    receive(net, self, msg);
    receive(net, self, msg);
    limited_inbox_actor_done <= true;
    wait;
  end process limited_inbox_actor;

  limited_inbox_subscriber : process is
    variable self    : actor_t;
    variable msg : msg_t;
  begin
    wait until start_limited_inbox_subscriber;
    self := create("limited inbox subscriber", 1);
    subscribe(self, find("test runner"));
    wait for 10 ns;
    receive(net, self, msg);
    wait;
  end process limited_inbox_subscriber;

end test_fixture;
