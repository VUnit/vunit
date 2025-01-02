-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

entity tb_com is
  generic(
    runner_cfg : string);
end entity tb_com;

architecture test_fixture of tb_com is
  signal hello_world_received, start_receiver, start_server         : boolean                  := false;
  signal start_server2, start_server3, start_server4, start_server5 : boolean                  := false;
  signal start_server6, start_subscribers, start_publishers         : boolean                  := false;
  signal hello_subscriber_received                                  : std_logic_vector(1 to 2) := "ZZ";
  signal start_limited_inbox, limited_inbox_actor_done              : boolean                  := false;
  signal start_limited_inbox_subscriber                             : boolean                  := false;

  constant com_logger : logger_t := get_logger("vunit_lib:com");
begin
  test_runner : process
    variable self, actor, actor2, actor3, actor4                : actor_t;
    variable actor5, my_receiver, my_sender, server, publisher  : actor_t;
    variable subscriber : actor_t;
    variable actor_vec                                          : actor_vec_t(0 to 2);
    variable status                                             : com_status_t;
    variable n_actors                                           : natural;
    variable t_start, t_stop                                    : time;
    variable ack                                                : boolean;
    variable msg, msg2, msg3, msg4                              : msg_t;
    variable request_msg, request_msg2, request_msg3, reply_msg : msg_t;
    variable peeked_msg1, peeked_msg2                           : msg_t;
    variable deprecated_message                                 : message_ptr_t;
    variable actor_state                                        : actor_state_t;
    variable mailbox_state                                      : mailbox_state_t;
    variable l                                                  : line;
    variable messenger_state                                    : messenger_state_t;
    variable null_mailbox_state                                 : mailbox_state_t   := (inbox, 0, null);
    variable null_actor_state                                   : actor_state_t     := (null,
                                                                                        false,
                                                                                        null_mailbox_state,
                                                                                        null_mailbox_state,
                                                                                        null, null
                                                                                       );
    variable null_messenger_state                               : messenger_state_t := (null, null);
    variable id : id_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_messenger;
      self := new_actor("test runner");

      -- Create
      if run("Test that named actors can be created") then
        n_actors := num_of_actors;
        actor    := new_actor("actor");
        check(actor /= null_actor, "Failed to create named actor");
        check_equal(name(actor), "actor");
        check(get_id(actor) = get_id("actor"));
        check_equal(num_of_actors, n_actors + 1, "Expected one extra actor");
        check(new_actor("other actor").p_id_number /= new_actor("another actor").p_id_number, "Failed to create unique actors");
        check_equal(num_of_actors, n_actors + 3, "Expected two extra actors");

      elsif run("Test that actors can be created from identities") then
        n_actors := num_of_actors;
        id := get_id("actor");
        actor := new_actor(id);
        check(actor /= null_actor, "Failed to create actor from identity");
        check_equal(name(actor), "actor");
        check(get_id(actor) = id);
        check_equal(num_of_actors, n_actors + 1, "Expected one extra actor");
        check(new_actor(get_id("other actor")).p_id_number /= new_actor(get_id("another actor")).p_id_number, "Failed to create unique actors");
        check_equal(num_of_actors, n_actors + 3, "Expected two extra actors");

      elsif run("Test that no name actors can be created") then
        actor := new_actor;
        check(actor /= null_actor, "Failed to create no name actor");
        check_equal(name(actor)(1 to 7), "_actor_");
        check(get_id(actor) /= null_id);

      elsif run("Test that null_id actors can be created") then
        actor := new_actor(null_id);
        check(actor /= null_actor, "Failed to create no name actor");
        check_equal(name(actor)(1 to 7), "_actor_");
        check(get_id(actor) /= null_id);

      elsif run("Test that the null actor has no name and identity") then
        check_equal(name(null_actor), "");
        check(get_id(actor) = null_id);

      elsif run("Test that two actors with the same name/identity cannot be created") then
        actor := new_actor("actor2");
        mock(com_logger);
        actor := new_actor("actor2");
        check_only_log(com_logger, "DUPLICATE ACTOR NAME ERROR.", failure);
        unmock(com_logger);

        actor := new_actor(get_id("actor3"));
        mock(com_logger);
        actor := new_actor(get_id("actor3"));
        check_only_log(com_logger, "DUPLICATE ACTOR NAME ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that no actor can be created for root_id") then
        mock(com_logger);
        actor := new_actor(root_id);
        check_only_log(com_logger, "NEW ACTOR FROM ROOT ID ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that multiple no-name actors can be created by name") then
        n_actors := num_of_actors;
        actor    := new_actor;
        actor2   := new_actor;
        check(actor.p_id_number /= actor2.p_id_number, "The two actors must have different identities");
        check_equal(num_of_actors, n_actors + 2);
        check_equal(num_of_deferred_creations, 0);

      elsif run("Test that multiple no-name actors can be created by id") then
        n_actors := num_of_actors;
        actor    := new_actor(null_id);
        actor2   := new_actor(null_id);
        check(actor.p_id_number /= actor2.p_id_number, "The two actors must have different identities");
        check_equal(num_of_actors, n_actors + 2);
        check_equal(num_of_deferred_creations, 0);

      -- Find
      elsif run("Test that a created actor can be found by name") then
        actor := new_actor("actor to be found");
        check(find("actor to be found", false) /= null_actor, "Failed to find created actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        check_false(is_deferred(actor));

      elsif run("Test that a created actor can be found by id") then
        id := get_id("actor to be found");
        actor := new_actor(id);
        check(find(id, false) /= null_actor, "Failed to find created actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        check_false(is_deferred(actor));

      elsif run("Test that an actor not created is found by name and its creation is deferred") then
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        actor := find("actor with deferred creation");
        check(actor /= null_actor, "Failed to find actor with deferred creation");
        check_equal(num_of_deferred_creations, 1, "Expected one deferred creations");
        check(is_deferred(actor));

      elsif run("Test that an actor not created is found by id and its creation is deferred") then
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        actor := find(get_id("actor with deferred creation"));
        check(actor /= null_actor, "Failed to find actor with deferred creation");
        check_equal(num_of_deferred_creations, 1, "Expected one deferred creations");
        check(is_deferred(actor));

      elsif run("Test that deferred creation can be suppressed when an actor is not found by name") then
        actor  := new_actor("actor");
        actor2 := find("actor with deferred creation", false);
        check(actor2 = null_actor, "Didn't expect to find any actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");

      elsif run("Test that deferred creation can be suppressed when an actor is not found by id") then
        actor  := new_actor("actor");
        actor2 := find(get_id("actor with deferred creation"), false);
        check(actor2 = null_actor, "Didn't expect to find any actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");

      elsif run("Test that a created actor by name gets the correct mailbox size") then
        actor := new_actor("actor with max inbox");
        check_equal(mailbox_size(actor), positive'high, result("for inbox size"));
        check_equal(mailbox_size(actor, outbox), positive'high, result("for outbox size"));

        actor2 := new_actor("actor with bounded inbox", 23, 17);
        check_equal(mailbox_size(actor2), 23, result("for inbox size"));
        check_equal(mailbox_size(actor2, outbox), 17, result("for outbox size"));

        check_equal(mailbox_size(null_actor), 0, result("for inbox size"));
        check_equal(mailbox_size(null_actor, outbox), 0, result("for outbox size"));

        check_equal(mailbox_size(find("actor to be created")), 1, result("for inbox size"));
        check_equal(mailbox_size(find("actor to be created"), outbox), positive'high, result("for outbox size"));

        check_equal(mailbox_size(new_actor("actor to be created", 42, 99)), 42, result("for inbox size"));
        check_equal(mailbox_size(find("actor to be created"), outbox), 99, result("for outbox size"));

      elsif run("Test that a created actor by id gets the correct mailbox size") then
        actor := new_actor(get_id("actor with max inbox"));
        check_equal(mailbox_size(actor), positive'high, result("for inbox size"));
        check_equal(mailbox_size(actor, outbox), positive'high, result("for outbox size"));

        actor2 := new_actor(get_id("actor with bounded inbox"), 23, 17);
        check_equal(mailbox_size(actor2), 23, result("for inbox size"));
        check_equal(mailbox_size(actor2, outbox), 17, result("for outbox size"));

        check_equal(mailbox_size(find(get_id("actor to be created"))), 1, result("for inbox size"));
        check_equal(mailbox_size(find(get_id("actor to be created")), outbox), positive'high, result("for outbox size"));

        check_equal(mailbox_size(new_actor(get_id("actor to be created"), 42, 99)), 42, result("for inbox size"));
        check_equal(mailbox_size(find(get_id("actor to be created")), outbox), 99, result("for outbox size"));

      elsif run("Test that mailboxes can be resized") then
        actor := new_actor("actor with max inbox");

        resize_mailbox(actor, 17);
        check_equal(mailbox_size(actor), 17, result("for inbox size"));
        check_equal(mailbox_size(actor, outbox), positive'high, result("for outbox size"));

        resize_mailbox(actor, 23, outbox);
        check_equal(mailbox_size(actor), 17, result("for inbox size"));
        check_equal(mailbox_size(actor, outbox), 23, result("for outbox size"));

        for i in 1 to 10 loop
          msg := new_msg;
          send(net, actor, msg);
        end loop;

        for i in 1 to 2 loop
          receive(net, actor, request_msg);
          reply_msg := new_msg;
          reply(net, request_msg, reply_msg);
        end loop;

        resize_mailbox(actor, 8);
        mock(com_logger);
        resize_mailbox(actor, 7);
        check_only_log(com_logger, "INSUFFICIENT SIZE ERROR.", failure);
        unmock(com_logger);

        resize_mailbox(actor, 2, outbox);
        mock(com_logger);
        resize_mailbox(actor, 1, outbox);
        check_only_log(com_logger, "INSUFFICIENT SIZE ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that no-name actors can't be found") then
        actor  := new_actor;
        actor2 := new_actor;
        check(find("") = null_actor, "Must not find a no-name actor");
        check_equal(num_of_deferred_creations, 0);

      elsif run("Test that null_id actors can't be found") then
        actor  := new_actor(null_id);
        actor2 := new_actor(null_id);
        check(find(null_id) = null_actor, "Must not find a null_id actor");
        check_equal(num_of_deferred_creations, 0);

      elsif run("Test that root_id actors can't be found") then
        actor  := new_actor(null_id);
        actor2 := new_actor(null_id);
        check(find(root_id) = null_actor, "Must not find a root_id actor");
        check_equal(num_of_deferred_creations, 0);

      -- Destroy
      elsif run("Test that a created actor can be destroyed") then
        actor    := new_actor("actor to destroy");
        actor2   := new_actor("actor to keep");
        n_actors := num_of_actors;
        destroy(actor);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(actor = null_actor, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor,
              "Actors other than the one destroyed must not be affected");

      elsif run("Test that a non-existing actor cannot be destroyed") then
        actor := null_actor;
        mock(com_logger);
        destroy(actor);
        check_only_log(com_logger, "UNKNOWN ACTOR ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that all actors can be destroyed") then
        reset_messenger;
        actor  := new_actor("actor to destroy");
        actor2 := new_actor("actor to destroy 2");
        check(num_of_actors = 2, "Expected two actors");
        reset_messenger;
        check(num_of_actors = 0, "Failed to destroy all actors");

      -- Copy and delete message
      elsif run("Test that a message can be deleted") then
        my_sender   := new_actor("my sender");
        my_receiver := new_actor("my receiver");

        msg            := new_msg;
        msg.id         := 17;
        msg.status     := timeout;
        msg.sender     := my_sender;
        msg.receiver   := my_receiver;
        msg.request_id := 21;
        push_string(msg, "hello");

        delete(msg);

        check_equal(msg.id, no_message_id);
        check(msg.status = null_message_error);
        check(msg.sender = null_actor);
        check(msg.receiver = null_actor);
        check_equal(msg.request_id, no_message_id);
        check(msg.data = null_queue);

      elsif run("Test that a message can be copied") then
        my_sender   := new_actor("my sender");
        my_receiver := new_actor("my receiver");

        msg            := new_msg;
        msg.id         := 17;
        msg.status     := timeout;
        msg.sender     := my_sender;
        msg.receiver   := my_receiver;
        msg.request_id := 21;
        push_string(msg, "hello");

        msg2 := copy(msg);
        push_string(msg, "world");
        delete(msg);
        msg  := new_msg;
        push_string(msg, "peanuts");

        check_equal(msg2.id, 17);
        check(msg2.status = timeout);
        check(msg2.sender = my_sender);
        check(msg2.receiver = my_receiver);
        check_equal(msg2.request_id, 21);
        check_equal(pop_string(msg2), "hello");

      -- to_string
      elsif run("Test string representation of message") then
        my_sender   := new_actor("my sender");
        my_receiver := new_actor("my receiver");

        msg            := new_msg;
        check_equal(to_string(msg), "-:- - -> - (-)");
        msg            := new_msg(new_msg_type("msg type"));
        check_equal(to_string(msg), "-:- - -> - (msg type)");
        msg.id         := 1;
        check_equal(to_string(msg), "1:- - -> - (msg type)");
        msg.sender     := my_sender;
        check_equal(to_string(msg), "1:- my sender -> - (msg type)");
        msg.receiver   := my_receiver;
        check_equal(to_string(msg), "1:- my sender -> my receiver (msg type)");
        msg.request_id := 7;
        check_equal(to_string(msg), "1:7 my sender -> my receiver (msg type)");

      -- Send and receive
      elsif run("Test that data ownership is lost at send") then
        msg := new_msg;
        push_string(msg, "hello");
        send(net, self, msg);
        check(msg.data = null_queue);

      elsif run("Test that an actor can send a message to another actor") then
        start_receiver <= true;
        wait for 1 ns;
        my_receiver    := find("my_receiver");
        msg            := new_msg(sender => self);
        push_string(msg, "hello world");
        send(net, my_receiver, msg);
        check(msg.sender = self);
        check(msg.receiver = my_receiver);
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");

      elsif run("Test that an actor can send a reply to a message from an a priori unknown actor") then
        start_server <= true;
        wait for 1 ns;
        server       := find("server");
        request_msg  := new_msg(sender => self);
        push_string(request_msg, "request");
        send(net, server, request_msg);
        receive(net, self, reply_msg);
        check(reply_msg.status = ok, "Expected no receive problems");
        check_equal(pop_string(reply_msg), "request acknowledge");

      elsif run("Test that an actor can send a message to itself") then
        msg := new_msg;
        push_string(msg, "hello");
        send(net, self, msg);
        receive(net, self, msg2);
        check(msg2.status = ok, "Expected no receive problems");
        check_equal(pop_string(msg2), "hello");

      elsif run("Test that no-name actors can communicate") then
        actor := new_actor;
        msg   := new_msg;
        push_string(msg, "hello");
        send(net, actor, msg);
        receive(net, actor, msg2);
        check_equal(pop_string(msg2), "hello");

      elsif run("Test that many back-to-back messages don't hit the simulator's delta cycle limit") then
        actor := new_actor;
        for iter in 1 to 10000 loop
          msg   := new_msg;
          push(msg, iter);
          send(net, actor, msg);
        end loop;
        for iter in 1 to 10000 loop
          receive(net, actor, msg2);
          check_equal(pop_integer(msg2), iter);
        end loop;

      elsif run("Test that an actor can poll for incoming messages") then
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected timeout");
        msg := new_msg(sender => self);
        push_string(msg, "hello again");
        send(net, self, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = ok, "Expected ok status");
        get_message(net, self, msg2);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(pop_string(msg2), "hello again");
        check(msg2.sender = self, "Expected message from myself");

      elsif run("Test that sending to a non-existing actor results in an error") then
        msg := new_msg;
        push_string(msg, "hello");
        mock(com_logger);
        send(net, null_actor, msg);
        check_only_log(com_logger, "UNKNOWN RECEIVER ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that an actor can send to an actor with deferred creation") then
        actor := find("deferred actor");
        msg   := new_msg;
        push_string(msg, "hello actor to be created");
        send(net, actor, msg);
        actor := new_actor("deferred actor");
        receive(net, actor, msg2);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(pop_string(msg2), "hello actor to be created");

      elsif run("Test that receiving from an actor with deferred creation results in an error") then
        actor := find("deferred actor");
        mock(com_logger);
        receive(net, actor, msg);
        check_log(com_logger, "DEFERRED RECEIVER ERROR.", failure);
        check_only_log(com_logger, "DEFERRED RECEIVER ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that empty messages can be sent") then
        msg := new_msg;
        send(net, self, msg);
        receive(net, self, msg2);
        check(msg2.status = ok, "Expected no problems with receive");
        check_equal(length(msg2.data), 0);

      elsif run("Test that each sent message gets an increasing message number") then
        msg := new_msg;
        send(net, self, msg);
        check(msg.id = 1, "Expected first receipt id to be 1");
        msg := new_msg;
        send(net, self, msg);
        check(msg.id = 2, "Expected first receipt id to be 2");
        receive(net, self, msg2);
        check(msg2.id = 1, "Expected first message id to be 1");
        receive(net, self, msg2);
        check(msg2.id = 2, "Expected first message id to be 2");

      elsif run("Test that each published message gets an increasing message number") then
        for i in actor_vec'range loop
          actor_vec(i) := new_actor;
          subscribe(actor_vec(i), self);
        end loop;

        for j in 1 to 3 loop
          msg := new_msg;
          publish(net, self, msg);
          for i in actor_vec'range loop
            receive(net, actor_vec(i), msg);
            check_equal(msg.id, j);
          end loop;
        end loop;

      elsif run("Test that a limited-inbox receiver can receive as expected without blocking") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        t_start             := now;
        msg                 := new_msg;
        push_string(msg, "First message");
        send(net, actor, msg);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on first message");
        t_start             := now;
        msg                 := new_msg;
        push_string(msg, "Second message");
        send(net, actor, msg, 0 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on second message");
        t_start             := now;
        msg                 := new_msg;
        push_string(msg, "Third message");
        send(net, actor, msg, 11 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 10 ns, "Expected a 10 ns blocking period on third message");

        wait until limited_inbox_actor_done;

      elsif run("Test that sending to a limited-inbox receiver times out as expected") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        msg                 := new_msg;
        push_string(msg, "First message");
        send(net, actor, msg);
        msg                 := new_msg;
        push_string(msg, "Second message");
        send(net, actor, msg, 0 ns);
        msg                 := new_msg;
        push_string(msg, "Third message");
        mock(com_logger);
        send(net, actor, msg, 9 ns);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_only_log(com_logger, "[3:- - -> limited inbox (-)] => limited inbox inbox", trace);
        unmock(com_logger);

      elsif run("Test that messages can be awaited from several actors") then
        actor  := new_actor;
        actor2 := new_actor;
        msg    := new_msg;
        push_string(msg, "To actor");
        send(net, actor, msg);
        wait_for_message(net, actor_vec_t'(actor, actor2), status);
        check(status = ok, "Expected ok status");
        check_true(has_message(actor));
        check_false(has_message(actor2));
        get_message(net, actor, msg);
        check_equal(pop_string(msg), "To actor");
        msg    := new_msg;
        push_string(msg, "To actor2");
        send(net, actor2, msg);
        wait_for_message(net, actor_vec_t'(actor, actor2), status);
        check(status = ok, "Expected ok status");
        check_true(has_message(actor2));
        check_false(has_message(actor));
        get_message(net, actor2, msg);
        check_equal(pop_string(msg), "To actor2");

      elsif run("Test sending to several actors") then
        actor_vec := (new_actor, new_actor, new_actor);
        for n in 0 to 2 loop
          msg := new_msg;
          push_string(msg, "hello");
          send(net, actor_vec(1 to n), msg);
          check(msg.data = null_queue);
          for i in 1 to n loop
            receive(net, actor_vec(i), msg, 0 ns);
            check_equal(pop_string(msg), "hello");
          end loop;
        end loop;

      elsif run("Test sending to several actors with timeout") then
        actor_vec := (new_actor(inbox_size => 1), new_actor(inbox_size => 1), new_actor(inbox_size => 1));
        msg       := new_msg;
        push_string(msg, "hello");
        send(net, actor_vec, msg);
        mock(com_logger);
        msg       := new_msg;
        push_string(msg, "hello");
        t_start   := now;
        send(net, actor_vec, msg, 10 ns);
        check_equal(now - t_start, 10 ns);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_log(com_logger, "[4:- - -> _actor_" & to_string(actor_vec(0).p_id_number) & " (-)] => _actor_" & to_string(actor_vec(0).p_id_number) & " inbox", trace);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_log(com_logger, "[5:- - -> _actor_" & to_string(actor_vec(1).p_id_number) & " (-)] => _actor_" & to_string(actor_vec(1).p_id_number) & " inbox", trace);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_log(com_logger, "[6:- - -> _actor_" & to_string(actor_vec(2).p_id_number) & " (-)] => _actor_" & to_string(actor_vec(2).p_id_number) & " inbox", trace);
        unmock(com_logger);

      elsif run("Test receiving from several actors") then
        for i in 0 to 2 loop
          actor_vec(i) := new_actor;
          subscribe(actor_vec(i), find("publisher " & to_string(i)));
        end loop;
        start_publishers <= true;
        receive(net, actor_vec(0 to 0), msg);
        check_equal(name(msg.sender), pop_string(msg));
        for i in 1 to 2 loop
          receive(net, actor_vec(1 to 2), msg);
          check_equal(name(msg.sender), pop_string(msg));
        end loop;

      elsif run("Test that the sender and the receiver of a message can be retrieved") then
        actor  := new_actor;
        actor2 := new_actor;
        msg    := new_msg(sender => actor2);
        push_string(msg, "To actor");
        send(net, actor, msg);
        receive(net, actor, msg);
        check(sender(msg) = actor2);
        check(receiver(msg) = actor);
        msg    := new_msg;
        push_string(msg, "To actor");
        send(net, actor, msg);
        receive(net, actor, msg);
        check(sender(msg) = null_actor);
        check(receiver(msg) = actor);

      elsif run("Test that get_message will wake up sender blocking on full inbox") then
        actor         := new_actor("actor", 1);
        start_server6 <= true;
        wait for 1 ns;
        server        := find("server6");

        request_msg := new_msg(sender => actor);
        push_string(request_msg, "request1");
        send(net, server, request_msg);

        request_msg2 := new_msg(sender => actor);
        push_string(request_msg2, "request2");
        send(net, server, request_msg2);

        wait_for_message(net, actor, status);
        get_message(net, actor, reply_msg);
        check_equal(pop_string(reply_msg), "reply to request1");

        wait_for_message(net, actor, status);
        get_message(net, actor, reply_msg);
        check_equal(pop_string(reply_msg), "reply to request2");

      elsif run("Test that a message can be forwarded") then
        actor  := new_actor("actor");
        actor2 := new_actor("actor2");
        actor3 := new_actor("actor3");
        msg    := new_msg(sender => actor);
        push_string(msg, "request");
        send(net, actor2, msg);
        receive(net, actor2, msg2);
        msg3   := new_msg;
        push_msg_t(msg3, msg2);
        send(net, actor3, msg3);
        receive(net, actor3, msg3);
        msg2   := new_msg;
        push_string(msg2, "reply");
        msg4   := pop_msg_t(msg3);
        reply(net, msg4, msg2);
        receive_reply(net, msg, msg3);
        check_equal(pop_string(msg3), "reply");
        check(sender(msg3) = actor2);
        check(receiver(msg3) = actor);

      -- Publish, subscribe, and unsubscribe
      elsif run("Test that an actor can publish messages to multiple subscribers") then
        publisher         := new_actor("publisher");
        start_subscribers <= true;
        wait for 1 ns;
        msg               := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, publisher, msg);
        check(msg.sender = publisher);
        check(msg.receiver = null_actor);
        wait until hello_subscriber_received = "11" for 1 ns;
        check(hello_subscriber_received = "11", "Expected ""hello subscribers"" to be received at the subscribers");

      elsif run("Test that subscribers receive messages sent on outbound subscription") then
        my_sender   := new_actor;
        my_receiver := new_actor;
        subscribe(self, my_sender, outbound);

        msg := new_msg(sender => my_sender);
        push_string(msg, "hello");
        send(net, my_receiver, msg);

        receive(net, my_receiver, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        receive(net, self, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        msg := new_msg;
        push_string(msg, "hello2");
        publish(net, my_sender, msg);

        receive(net, self, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = self);
        check_equal(pop_string(msg2), "hello2");

      elsif run("Test that subscribers don't receive duplicate message") then
        publisher := new_actor("publisher");
        subscribe(self, publisher);

        msg := new_msg(sender => publisher);
        push_string(msg, "hello");
        send(net, self, msg);

        receive(net, self, msg2, 0 ns);
        check(msg2.receiver = self);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected only one message");

      elsif run("Test that actors don't get send messages on a publish subscription") then
        publisher := new_actor("publisher");
        subscribe(self, publisher);

        msg := new_msg(sender => publisher);
        push_string(msg, "hello");
        send(net, publisher, msg);

        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");

      elsif run("Test that actors can subscribe to inbound traffic") then
        my_receiver := new_actor;
        subscribe(self, my_receiver, inbound);

        msg := new_msg;
        push_string(msg, "hello");
        send(net, my_receiver, msg);

        receive(net, my_receiver, msg2, 0 ns);
        check(sender(msg2) = null_actor);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        receive(net, self, msg2, 0 ns);
        check(sender(msg2) = null_actor);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        msg := new_msg;
        push_string(msg, "publication");
        publish(net, my_receiver, msg);

        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");

        actor := new_actor("actor");
        msg   := new_msg(sender => my_receiver);
        push_string(msg, "hello");

        send(net, actor, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");

      elsif run("Test request/reply with actor having inbound subscribers") then
        subscriber    := new_actor("subscriber");
        start_server5 <= true;
        wait for 1 ns;
        server        := find("server5");
        subscribe(subscriber, server, inbound);

        request_msg := new_msg(sender => self);
        push_string(request_msg, "request");
        send(net, server, request_msg);

        receive_reply(net, request_msg, reply_msg, 100 ns);
        check_equal(pop_string(reply_msg), "reply");

        receive(net, subscriber, reply_msg, 0 ns);
        check_equal(pop_string(reply_msg), "request");

      elsif run("Test chained subscribers") then
        my_sender   := new_actor;
        my_receiver := new_actor;
        subscriber  := new_actor;
        subscribe(self, my_sender, outbound);
        subscribe(subscriber, self, inbound);

        msg := new_msg(sender => my_sender);
        push_string(msg, "hello");
        send(net, my_receiver, msg);

        receive(net, my_receiver, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        receive(net, self, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        receive(net, subscriber, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = my_receiver);
        check_equal(pop_string(msg2), "hello");

        msg := new_msg;
        push_string(msg, "hello2");
        publish(net, my_sender, msg);

        receive(net, self, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = self);
        check_equal(pop_string(msg2), "hello2");

        receive(net, subscriber, msg2, 0 ns);
        check(sender(msg2) = my_sender);
        check(receiver(msg2) = self, "Got: " & name(receiver(msg2)));
        check_equal(pop_string(msg2), "hello2");

      elsif run("Test that a subscriber can unsubscribe") then
        subscribe(self, self, published);
        subscribe(self, self, inbound);
        unsubscribe(self, self, inbound);
        msg := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg);
        receive(net, self, msg, 0 ns);
        check_equal(pop_string(msg), "hello subscriber");
        unsubscribe(self, self, published);
        msg := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg);
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");

      elsif run("Test that a destroyed subscriber is not addressed by the publisher") then
        subscriber := new_actor("subscriber");
        subscribe(subscriber, self);
        msg        := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg);
        receive(net, subscriber, msg, 0 ns);
        check_equal(pop_string(msg), "hello subscriber");
        destroy(subscriber);
        push_string(msg, "hello subscriber");
        publish(net, self, msg);

      elsif run("Test that an actor can only subscribe once to the same publisher") then
        subscribe(self, self);
        mock(com_logger);
        subscribe(self, self);
        check_only_log(com_logger, "ALREADY A SUBSCRIBER ERROR.", failure);
        unmock(com_logger);

      elsif run("Test that publishing to subscribers with full inboxes results is an error") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        msg                            := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg);
        msg                            := new_msg;
        push_string(msg, "hello subscriber");
        mock(com_logger);
        publish(net, self, msg, 8 ns);
        check_log(com_logger, "FULL INBOX ERROR.", failure);
        check_only_log(com_logger,
                       "[2:- test runner -> limited inbox subscriber (-)] => limited inbox subscriber inbox",
                       trace);
        unmock(com_logger);

      elsif run("Test that publishing to subscribers with full inboxes results passes if waiting") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        msg                            := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg);
        msg                            := new_msg;
        push_string(msg, "hello subscriber");
        publish(net, self, msg, 11 ns);

      -- Request, (receive_)reply and acknowledge
      elsif run("Test that a client can wait for an out-of-order request reply") then
        start_server2 <= true;
        server        := find("server2");

        request_msg  := new_msg(sender => self);
        push_string(request_msg, "request1");
        send(net, server, request_msg);

        request_msg2 := new_msg(sender => self);
        push_string(request_msg2, "request2");
        send(net, server, request_msg2);

        receive_reply(net, request_msg, ack);
        check_false(ack, "Expected negative acknowledgement");

        request_msg3 := new_msg(sender => self);
        push_string(request_msg3, "request3");
        send(net, server, request_msg3);

        receive_reply(net, request_msg3, ack);
        check(ack, "Expected positive acknowledgement");

        receive_reply(net, request_msg2, reply_msg);
        check(reply_msg.sender = server);
        check(reply_msg.receiver = self);
        check_equal(pop_string(reply_msg), "reply2");
        check_equal(reply_msg.request_id, request_msg2.id);

      elsif run("Test that a synchronous request can be made") then
        start_server3 <= true;
        server        := find("server3");

        request_msg := new_msg(sender => self);
        push_string(request_msg, "request1");
        request(net, server, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply1");

        request_msg := new_msg(sender => self);
        push_string(request_msg, "request2");
        request(net, server, request_msg, ack);
        check(ack, "Expected positive acknowledgement");

        request_msg := new_msg(sender => self);
        push_string(request_msg, "request3");
        request(net, server, request_msg, ack);
        check_false(ack, "Expected negative acknowledgement");

      elsif run("Test that waiting and getting a reply with timeout works") then
        start_server4 <= true;
        server        := find("server4");

        t_start     := now;
        request_msg := new_msg(sender => self);
        push_string(request_msg, "request1");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        t_start     := now;
        request_msg := new_msg;
        push_string(request_msg, "request2");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        request_msg := new_msg(sender => self);
        push_string(request_msg, "request3");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status);
        get_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply3");

        t_start     := now;
        request_msg := new_msg;
        push_string(request_msg, "request4");
        send(net, server, request_msg);
        wait_for_reply(net, request_msg, status);
        get_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply4");

      elsif run("Test waiting and getting a reply out-of-order") then
        start_server2 <= true;
        server        := find("server2");

        request_msg  := new_msg(sender => self);
        push_string(request_msg, "request1");
        send(net, server, request_msg);

        request_msg2 := new_msg(sender => self);
        push_string(request_msg2, "request2");
        send(net, server, request_msg2);

        wait_for_reply(net, request_msg, status);
        check(status = ok);

        get_reply(net, request_msg, reply_msg);
        check_false(pop_boolean(reply_msg));

        request_msg3 := new_msg(sender => self);
        push_string(request_msg3, "request3");
        send(net, server, request_msg3);

        wait_for_reply(net, request_msg3, status);
        check(status = ok);

        get_reply(net, request_msg3, reply_msg);
        check(pop_boolean(reply_msg));

        wait_for_reply(net, request_msg2, status);
        check(status = ok);

        get_reply(net, request_msg2, reply_msg);
        check_equal(pop_string(reply_msg), "reply2");

      elsif run("Test that an anonymous request can be made") then
        start_server5 <= true;
        server        := find("server5");

        request_msg := new_msg;
        push_string(request_msg, "request");
        send(net, server, request_msg);
        wait for 10 ns;
        receive_reply(net, request_msg, reply_msg);
        check(reply_msg.sender = server);
        check(reply_msg.receiver = null_actor);
        check_equal(pop_string(reply_msg), "reply");
        check_equal(reply_msg.request_id, request_msg.id);

        request_msg := new_msg;
        push_string(request_msg, "request2");
        send(net, server, request_msg);
        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply2");

        request_msg := new_msg;
        push_string(request_msg, "request3");
        send(net, server, request_msg);
        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply3");

      elsif run("Test that get_reply will wake up sender blocking on full inbox") then
        actor         := new_actor("actor", 1);
        start_server6 <= true;
        wait for 1 ns;
        server        := find("server6");

        request_msg := new_msg(sender => actor);
        push_string(request_msg, "request1");
        send(net, server, request_msg);

        request_msg2 := new_msg(sender => actor);
        push_string(request_msg2, "request2");
        send(net, server, request_msg2);

        receive_reply(net, request_msg, reply_msg);
        check_equal(pop_string(reply_msg), "reply to request1");

        receive_reply(net, request_msg2, reply_msg);
        check_equal(pop_string(reply_msg), "reply to request2");

      -- Timeout
      elsif run("Test that timeout on receive leads to an error") then
        mock(com_logger);
        receive(net, self, msg, 1 ns);
        check_only_log(com_logger, "TIMEOUT.", failure);
        unmock(com_logger);

      -- Debugging
      elsif run("Test getting the number of messages in a mailbox") then
        check_equal(num_of_messages(self), 0);
        msg := new_msg;
        send(net, self, msg);
        check_equal(num_of_messages(self), 1);
        msg := new_msg;
        send(net, self, msg);
        check_equal(num_of_messages(self), 2);
        receive(net, self, msg);
        check_equal(num_of_messages(self), 1);
        receive(net, self, msg);
        check_equal(num_of_messages(self), 0);

        check_equal(num_of_messages(self, outbox), 0);
        msg       := new_msg;
        send(net, self, msg);
        receive(net, self, request_msg);
        reply_msg := new_msg;
        reply(net, request_msg, reply_msg);
        check_equal(num_of_messages(self, outbox), 1);
        msg2      := new_msg;
        send(net, self, msg2);
        receive(net, self, request_msg);
        reply_msg := new_msg;
        reply(net, request_msg, reply_msg);
        check_equal(num_of_messages(self, outbox), 2);
        receive_reply(net, msg, reply_msg);
        check_equal(num_of_messages(self, outbox), 1);
        receive_reply(net, msg2, reply_msg);
        check_equal(num_of_messages(self, outbox), 0);

      elsif run("Test peeking at messages in a mailbox") then
        actor       := new_actor;
        mock(com_logger);
        peeked_msg1 := peek_message(actor);
        check_only_log(com_logger, "Peeking non-existing position.", failure);
        unmock(com_logger);

        msg         := new_msg;
        send(net, actor, msg);
        msg         := new_msg;
        send(net, actor, msg);
        peeked_msg1 := peek_message(actor);
        peeked_msg2 := peek_message(actor, 1);
        receive(net, actor, msg);
        check(peeked_msg1 = msg);
        receive(net, actor, msg);
        check(peeked_msg2 = msg);

        msg  := new_msg;
        send(net, actor, msg);
        msg2 := new_msg;
        send(net, actor, msg2);

        mock(com_logger);
        peeked_msg1 := peek_message(actor, 0, outbox);
        check_only_log(com_logger, "Peeking non-existing position.", failure);
        unmock(com_logger);

        receive(net, actor, request_msg);
        reply_msg := new_msg;
        reply(net, request_msg, reply_msg);
        receive(net, actor, request_msg);
        reply_msg := new_msg;
        reply(net, request_msg, reply_msg);

        peeked_msg1 := peek_message(actor, 0, outbox);
        peeked_msg2 := peek_message(actor, 1, outbox);

        receive_reply(net, msg, reply_msg);
        check(peeked_msg1 = reply_msg);
        receive_reply(net, msg2, reply_msg);
        check(peeked_msg2 = reply_msg);

      elsif run("Test getting and deallocating mailbox state") then
        actor         := new_actor("actor", 17, 23);
        msg           := new_msg;
        send(net, actor, msg);
        mailbox_state := get_mailbox_state(actor);
        check(mailbox_state.id = inbox);
        check(mailbox_state.size = 17);
        receive(net, actor, request_msg);
        check(mailbox_state.messages(0) = request_msg);

        reply_msg     := new_msg;
        reply(net, request_msg, reply_msg);
        mailbox_state := get_mailbox_state(actor, outbox);
        check(mailbox_state.id = outbox);
        check(mailbox_state.size = 23);
        receive_reply(net, msg, reply_msg);
        check(mailbox_state.messages(0) = reply_msg);

        deallocate(mailbox_state);
        check(mailbox_state = null_mailbox_state);

      elsif run("Test making a string of mailbox state") then
        actor := new_actor("actor", 17);
        check_equal(get_mailbox_state_string(actor, inbox),
                    "Mailbox: inbox" & LF & "  Size: 17" & LF & "  Messages:");

        msg           := new_msg(sender => self);
        send(net, actor, msg);
        msg           := new_msg;
        send(net, actor, msg);
        mailbox_state := get_mailbox_state(actor);
        write(l, get_mailbox_state_string(actor, inbox, "  "));
        receive(net, actor, request_msg);
        info(l.all);
        check_equal(
          l.all,
          "  Mailbox: inbox" & LF & "    Size: 17" & LF & "    Messages:" & LF & "      0. " & --
          to_string(mailbox_state.messages(0)) & LF & "      1. " & to_string(mailbox_state.messages(1))
        );

      elsif run("Test getting and deallocating actor state") then
        actor       := find("my actor");
        actor_state := get_actor_state(actor);
        check_equal(actor_state.name.all, "my actor");
        check(actor_state.is_deferred);
        deallocate(actor_state);
        check(actor_state = null_actor_state);

        actor       := new_actor("my actor", 17, 21);
        actor_state := get_actor_state(actor);
        check_false(actor_state.is_deferred);

        msg         := new_msg;
        send(net, actor, msg);
        actor_state := get_actor_state(actor);
        receive(net, actor, request_msg);
        check(actor_state.inbox.id = inbox);
        check(actor_state.inbox.size = 17);
        check(actor_state.inbox.messages(0) = request_msg);

        reply_msg   := new_msg;
        reply(net, request_msg, reply_msg);
        actor_state := get_actor_state(actor);
        receive_reply(net, msg, reply_msg);
        check(actor_state.outbox.id = outbox);
        check(actor_state.outbox.size = 21);
        check(actor_state.outbox.messages(0) = reply_msg);
        deallocate(actor_state);
        check(actor_state = null_actor_state);

        actor2      := new_actor;
        subscribe(actor, actor2, inbound);
        subscribe(self, actor);
        actor_state := get_actor_state(actor);
        check(actor_state.subscriptions(0) = subscription_t'(subscriber   => actor,
                                                             publisher    => actor2,
                                                             traffic_type => inbound
                                                            )
        );
        check(actor_state.subscribers(0) = subscription_t'(subscriber   => self,
                                                           publisher    => actor,
                                                           traffic_type => published
                                                          )
        );
        deallocate(actor_state);
        check(actor_state = null_actor_state);

      elsif run("Test making a string of actor state") then
        actor := find("my actor");
        check_equal(get_actor_state_string(actor),
                    "Name: my actor" & LF & "  Is deferred: yes" & LF & --
                    get_mailbox_state_string(actor, inbox, "  ") & LF & --
                    get_mailbox_state_string(actor, outbox, "  ") & LF & --
                    "  Subscriptions:" & LF & "  Subscribers:");

        actor := new_actor("my actor");
        msg   := new_msg;
        send(net, actor, msg);

        check_equal(get_actor_state_string(actor),
                    "Name: my actor" & LF & "  Is deferred: no" & LF & --
                    get_mailbox_state_string(actor, inbox, "  ") & LF & --
                    get_mailbox_state_string(actor, outbox, "  ") & LF & --
                    "  Subscriptions:" & LF & "  Subscribers:");

        receive(net, actor, request_msg);
        reply_msg := new_msg;
        reply(net, request_msg, reply_msg);

        check_equal(get_actor_state_string(actor),
                    "Name: my actor" & LF & "  Is deferred: no" & LF & --
                    get_mailbox_state_string(actor, inbox, "  ") & LF & --
                    get_mailbox_state_string(actor, outbox, "  ") & LF & --
                    "  Subscriptions:" & LF & "  Subscribers:");

        actor2 := new_actor("actor 2");
        subscribe(actor, actor2);
        subscribe(actor, actor2, inbound);
        subscribe(self, actor, inbound);
        subscribe(self, actor, outbound);

        info(get_actor_state_string(actor));
        check_equal(get_actor_state_string(actor),
                    "Name: my actor" & LF & "  Is deferred: no" & LF & --
                    get_mailbox_state_string(actor, inbox, "  ") & LF & --
                    get_mailbox_state_string(actor, outbox, "  ") & LF & --
                    "  Subscriptions:" & LF & "    published traffic from actor 2" & LF & --
                    "    inbound traffic to actor 2" & LF & "  Subscribers:" & LF & --
                    "    test runner subscribes to outbound traffic" & LF & --
                    "    test runner subscribes to inbound traffic");

      elsif run("Test getting messenger and deallocating state") then
        reset_messenger;
        messenger_state := get_messenger_state;
        check(messenger_state = null_messenger_state);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

        actor           := new_actor("actor");
        messenger_state := get_messenger_state;
        check_equal(messenger_state.active_actors'length, 1);
        check(messenger_state.deferred_actors = null);
        actor_state     := get_actor_state(actor);
        check_equal(messenger_state.active_actors(0).name.all, actor_state.name.all);
        check_equal(messenger_state.active_actors(0).is_deferred, actor_state.is_deferred);
        check(messenger_state.active_actors(0).inbox = actor_state.inbox);
        check(messenger_state.active_actors(0).outbox = actor_state.outbox);
        check(messenger_state.active_actors(0).subscriptions = actor_state.subscriptions);
        check(messenger_state.active_actors(0).subscribers = actor_state.subscribers);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

        actor2          := new_actor("actor 2");
        messenger_state := get_messenger_state;
        check_equal(messenger_state.active_actors'length, 2);
        check(messenger_state.deferred_actors = null);
        actor_state     := get_actor_state(actor2);
        check_equal(messenger_state.active_actors(1).name.all, actor_state.name.all);
        check_equal(messenger_state.active_actors(1).is_deferred, actor_state.is_deferred);
        check(messenger_state.active_actors(1).inbox = actor_state.inbox);
        check(messenger_state.active_actors(1).outbox = actor_state.outbox);
        check(messenger_state.active_actors(1).subscriptions = actor_state.subscriptions);
        check(messenger_state.active_actors(1).subscribers = actor_state.subscribers);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

        destroy(actor);

        messenger_state := get_messenger_state;
        check_equal(messenger_state.active_actors'length, 1);
        check(messenger_state.deferred_actors = null);
        actor_state     := get_actor_state(actor2);
        check_equal(messenger_state.active_actors(0).name.all, actor_state.name.all);
        check_equal(messenger_state.active_actors(0).is_deferred, actor_state.is_deferred);
        check(messenger_state.active_actors(0).inbox = actor_state.inbox);
        check(messenger_state.active_actors(0).outbox = actor_state.outbox);
        check(messenger_state.active_actors(0).subscriptions = actor_state.subscriptions);
        check(messenger_state.active_actors(0).subscribers = actor_state.subscribers);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

        actor3          := find("actor 3");
        messenger_state := get_messenger_state;
        check_equal(messenger_state.active_actors'length, 1);
        check_equal(messenger_state.deferred_actors'length, 1);
        actor_state     := get_actor_state(actor2);
        check_equal(messenger_state.active_actors(0).name.all, actor_state.name.all);
        check_equal(messenger_state.active_actors(0).is_deferred, actor_state.is_deferred);
        check(messenger_state.active_actors(0).inbox = actor_state.inbox);
        check(messenger_state.active_actors(0).outbox = actor_state.outbox);
        check(messenger_state.active_actors(0).subscriptions = actor_state.subscriptions);
        check(messenger_state.active_actors(0).subscribers = actor_state.subscribers);
        actor_state     := get_actor_state(actor3);
        check_equal(messenger_state.deferred_actors(0).name.all, actor_state.name.all);
        check_equal(messenger_state.deferred_actors(0).is_deferred, actor_state.is_deferred);
        check(messenger_state.deferred_actors(0).inbox = actor_state.inbox);
        check(messenger_state.deferred_actors(0).outbox = actor_state.outbox);
        check(messenger_state.deferred_actors(0).subscriptions = actor_state.subscriptions);
        check(messenger_state.deferred_actors(0).subscribers = actor_state.subscribers);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

        destroy(actor2);

        messenger_state := get_messenger_state;
        check(messenger_state.active_actors = null);
        check_equal(messenger_state.deferred_actors'length, 1);
        actor_state     := get_actor_state(actor3);
        check_equal(messenger_state.deferred_actors(0).name.all, actor_state.name.all);
        check_equal(messenger_state.deferred_actors(0).is_deferred, actor_state.is_deferred);
        check(messenger_state.deferred_actors(0).inbox = actor_state.inbox);
        check(messenger_state.deferred_actors(0).outbox = actor_state.outbox);
        check(messenger_state.deferred_actors(0).subscriptions = actor_state.subscriptions);
        check(messenger_state.deferred_actors(0).subscribers = actor_state.subscribers);
        deallocate(messenger_state);
        check(messenger_state = null_messenger_state);

      elsif run("Test making a string of messenger state") then
        reset_messenger;
        check_equal(get_messenger_state_string,
                    "Active actors:" & LF & "Deferred actors:");

        actor := new_actor("actor");
        check_equal(get_messenger_state_string,
                    "Active actors:" & LF & get_actor_state_string(actor, "  ") & LF & LF & "Deferred actors:");

        actor2 := new_actor("actor 2");
        check_equal(get_messenger_state_string,
                    "Active actors:" & LF & get_actor_state_string(actor, "  ") & LF & LF & --
                    get_actor_state_string(actor2, "  ") & LF & LF & "Deferred actors:");

        actor3 := find("actor 3");
        actor4 := find("actor 4");
        actor5 := new_actor("actor 5");
        check_equal(get_messenger_state_string("  "),
                    "  Active actors:" & LF & get_actor_state_string(actor, "    ") & LF & LF & --
                    get_actor_state_string(actor2, "    ") & LF & LF & get_actor_state_string(actor5, "    ") & --
                    LF & LF & "  Deferred actors:" & LF & get_actor_state_string(actor3, "    ") & LF & --
                    LF & get_actor_state_string(actor4, "    "));

        destroy(actor);
        destroy(actor2);
        destroy(actor5);
        check_equal(get_messenger_state_string,
                    "Active actors:" & LF & "Deferred actors:" & LF & get_actor_state_string(actor3, "  ") & --
                    LF & LF & get_actor_state_string(actor4, "  "));

      elsif run("Test trace log") then
        mock(com_logger);
        my_sender   := new_actor("sender");
        my_receiver := new_actor("receiver");

        msg := new_msg(new_msg_type("msg type"), sender => my_sender);
        send(net, my_receiver, msg);
        check_only_log(com_logger, "[1:- sender -> receiver (msg type)] => receiver inbox", trace);
        receive(net, my_receiver, msg);
        check_only_log(com_logger, "receiver inbox => [1:- sender -> receiver (msg type)]", trace);

        request_msg := new_msg;
        send(net, my_receiver, request_msg);
        check_only_log(com_logger, "[2:- - -> receiver (-)] => receiver inbox", trace);
        receive(net, my_receiver, reply_msg);
        check_only_log(com_logger, "receiver inbox => [2:- - -> receiver (-)]", trace);

        reply(net, request_msg, reply_msg);
        check_only_log(com_logger, "[3:2 receiver -> - (-)] => receiver outbox", trace);
        receive_reply(net, request_msg, reply_msg);
        check_only_log(com_logger, "receiver outbox => [3:2 receiver -> - (-)]", trace);

        unmock(com_logger);

      elsif run("Test actor to/from integer conversion") then
        actor := new_actor;
        check(to_actor(to_integer(actor)) = actor);
        check(to_actor(to_integer(null_actor)) = null_actor);

      -- Deprecated APIs
      elsif run("Test that use of deprecated API leads to an error") then
        mock(com_logger);
        deprecated_message := compose("hello world");
        check_only_log(com_logger, "DEPRECATED INTERFACE ERROR. compose()", failure);
        unmock(com_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);

  my_receiver : process is
    variable self : actor_t;
    variable msg  : msg_t;
  begin
    wait until start_receiver;
    self                 := new_actor("my_receiver");
    receive(net, self, msg);
    check(msg.sender = find("test runner"));
    check(msg.receiver = self);
    hello_world_received <= check_equal(pop_string(msg), "hello world");
    wait;
  end process;

  server : process is
    variable self                   : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server;
    self := new_actor("server");
    receive(net, self, request_msg);
    if check_equal(pop_string(request_msg), "request") then
      reply_msg := new_msg;
      push_string(reply_msg, "request acknowledge");
      send(net, request_msg.sender, reply_msg);
    end if;
    wait;
  end process server;

  subscribers : for i in 1 to 2 generate
    process is
      variable self, publisher : actor_t;
      variable msg             : msg_t;
    begin
      wait until start_subscribers;
      self      := new_actor("subscriber " & integer'image(i));
      publisher := find("publisher");
      subscribe(self, publisher);
      receive(net, self, msg);
      check(sender(msg) = find("publisher"));
      check(receiver(msg) = self);
      if check_equal(pop_string(msg), "hello subscriber") then
        hello_subscriber_received(i)     <= '1';
        hello_subscriber_received(3 - i) <= 'Z';
      end if;
      wait;
    end process;
  end generate subscribers;

  server2 : process is
    variable self                                     : actor_t;
    variable request_msg1, request_msg2, request_msg3 : msg_t;
    variable reply_msg                                : msg_t;
  begin
    wait until start_server2;
    self := new_actor("server2");

    receive(net, self, request_msg1);
    check_equal(pop_string(request_msg1), "request1");

    receive(net, self, request_msg2);
    check_equal(pop_string(request_msg2), "request2");

    reply_msg := new_msg;
    push_string(reply_msg, "reply2");
    reply(net, request_msg2, reply_msg);
    check(reply_msg.sender = self);
    check(reply_msg.receiver = find("test runner"));

    acknowledge(net, request_msg1, false);

    receive(net, self, request_msg3);
    check_equal(pop_string(request_msg3), "request3");

    acknowledge(net, request_msg3, true);
    wait;
  end process server2;

  server3 : process is
    variable self                   : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server3;
    self := new_actor("server3");

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request1");
    reply_msg := new_msg;
    push_string(reply_msg, "reply1");
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request2");
    acknowledge(net, request_msg, true);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request3");
    acknowledge(net, request_msg, false);

    wait;
  end process server3;

  server4 : process is
    variable self                   : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server4;
    self := new_actor("server4", 1);

    receive(net, self, request_msg);
    receive(net, self, request_msg);
    receive(net, self, request_msg);
    reply_msg := new_msg;
    push_string(reply_msg, "reply3");
    reply(net, request_msg, reply_msg);
    receive(net, self, request_msg);
    reply_msg := new_msg;
    push_string(reply_msg, "reply4");
    reply(net, request_msg, reply_msg);
    wait;
  end process server4;

  server5 : process is
    variable self                   : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server5;
    self := new_actor("server5");

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request");
    reply_msg := new_msg;
    push_string(reply_msg, "reply");
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request2");
    reply_msg := new_msg;
    push_string(reply_msg, "reply2");
    wait for 10 ns;
    reply(net, request_msg, reply_msg);

    receive(net, self, request_msg);
    check_equal(pop_string(request_msg), "request3");
    reply_msg := new_msg;
    push_string(reply_msg, "reply3");
    reply(net, request_msg, reply_msg);

    wait;
  end process server5;

  server6 : process is
    variable self                   : actor_t;
    variable request_msg, reply_msg : msg_t;
  begin
    wait until start_server6;
    self := new_actor("server6");
    loop
      receive(net, self, request_msg);
      reply_msg := new_msg;
      push_string(reply_msg, "reply to " & pop_string(request_msg));
      reply(net, request_msg, reply_msg);
    end loop;
  end process server6;

  limited_inbox_actor : process is
    variable self : actor_t;
    variable msg  : msg_t;
  begin
    wait until start_limited_inbox;
    self                     := new_actor("limited inbox", 2);
    wait for 10 ns;
    receive(net, self, msg);
    receive(net, self, msg);
    receive(net, self, msg);
    limited_inbox_actor_done <= true;
    wait;
  end process limited_inbox_actor;

  limited_inbox_subscriber : process is
    variable self : actor_t;
    variable msg  : msg_t;
  begin
    wait until start_limited_inbox_subscriber;
    self := new_actor("limited inbox subscriber", 1);
    subscribe(self, find("test runner"));
    wait for 10 ns;
    receive(net, self, msg);
    wait;
  end process limited_inbox_subscriber;

  publishers : for i in 0 to 2 generate
    process is
      variable self : actor_t;
      variable msg  : msg_t;
    begin
      wait until start_publishers;
      self := new_actor("publisher " & integer'image(i));
      msg  := new_msg;
      push_string(msg, name(self));
      publish(net, self, msg);
      wait;
    end process;
  end generate publishers;

end test_fixture;
