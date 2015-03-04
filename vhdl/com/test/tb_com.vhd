-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library com_lib;
use com_lib.com_pkg.all;
use com_lib.com_types_pkg.all;

use std.textio.all;

entity tb_com is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_com;

architecture test_fixture of tb_com is
  signal hello_world_received, start_receiver, start_server : boolean := false;
  signal test : boolean := false;
begin
  test_runner : process
    variable actor_to_be_found, actor_with_deferred_creation, actor_to_destroy,
             actor_to_destroy_copy, actor_to_keep, actor, actor_duplicate,
             self, receiver, server, deferred_actor: actor_t;
    variable actor_destroy_status : actor_destroy_status_t;
    variable n_actors : natural;
    variable send_status : send_status_t;
    variable receive_status : receive_status_t;
    variable message : message_ptr_t;
  begin
    checker_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "error.csv"),
                 file_format => verbose_csv);    
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_messenger;
      self := create("test runner");
      if run("Test that named actors can be created") then
        check(create("actor") /= null_actor_c, "Failed to create named actor");
        check(num_of_actors = 2, "Expected two actors");
        check(create("other actor").id /= create("another actor").id, "Failed to create unique actors");
        check(num_of_actors = 4, "Expected three actors");
      elsif run("Test that no name actors can be created") then
        check(create /= null_actor_c, "Failed to create no name actor");
      elsif run("Test that two actors of the same name cannot be created") then
        actor := create("actor2");
        check(actor /= null_actor_c, "Failed to create named actor");
        check(create("actor2") = actor, "Was allowed to create an actor duplicate");
      elsif run("Test that a created actor can be found") then
        actor_to_be_found := create("actor to be found");
        check(find("actor to be found", false) /= null_actor_c, "Failed to find created actor");
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
      elsif run("Test that an actor not created is found and its creation is deferred") then
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
        actor_with_deferred_creation := find("actor with deferred creation");
        check(actor_with_deferred_creation /= null_actor_c, "Failed to find actor with deferred creation");
        check(num_of_deferred_creations = 1, "Expected one deferred creations");
      elsif run("Test that deferred creation can be suppressed when an actor is not found") then
        actor_with_deferred_creation := find("actor with deferred creation2", false);
        check(actor_with_deferred_creation = null_actor_c, "Didn't expect to find any actor");
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
      elsif run("Test that a created actor can be destroyed") then
        actor_to_destroy := create("actor to destroy");
        actor_to_keep := create("actor to keep");
        n_actors := num_of_actors;
        destroy(actor_to_destroy, actor_destroy_status);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(actor_destroy_status = ok, "Expected destroy status to be ok");
        check(actor_to_destroy = null_actor_c, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor_c, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor_c, "Actors other than the one destroyed must not be affected");
      elsif run("Test that a non-existing actor cannot be destroyed") then
        actor_to_destroy := create("actor to destroy");
        actor_to_destroy_copy := actor_to_destroy;
        n_actors := num_of_actors;
        destroy(actor_to_destroy, actor_destroy_status);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        destroy(actor_to_destroy_copy, actor_destroy_status);
        check(actor_destroy_status = unknown_actor_error, "Expected destroy to fail with unknown actor error");
        check(num_of_actors = n_actors - 1, "Expected no change in the number of actors");
      elsif run("Test that all actors can be destroyed") then
        reset_messenger;
        actor_to_destroy := create("actor to destroy 2");
        actor_to_destroy := create("actor to destroy 3");
        check(num_of_actors = 2, "Expected two actors");         
        reset_messenger;
        check(num_of_actors = 0, "Failed to destroy all actors");
      elsif run("Test that an actor can send a message to another actor") then
        start_receiver <= true;
        wait for 1 ns;
        receiver := find("receiver");
        send(net, receiver, "hello world", send_status);
        check(send_status = ok, "Expected send to succeed");
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");
      elsif run("Test that an actor can send a message in response to another message from an a priori unknown actor") then
        start_server <= true;
        wait for 1 ns;
        server := find("server");
        message := compose("request", self);        
        send(net, server, message, send_status);
        check(send_status = ok, "Expected send to succeed");
        receive(net, self, message, receive_status);
        if check(receive_status = ok, "Expected no receive problems") then
          check(message.payload.all = "request acknowledge", "Expected ""request acknowledge""");
        end if;
        delete(message);
      elsif run("Test that an actor can send a message to itself") then
        send(net, self, "hello", send_status);
        check(send_status = ok, "Expected send to succeed");
        receive(net, self, message, receive_status);
        if check(receive_status = ok, "Expected no receive problems") then        
          check(message.payload.all = "hello", "Expected ""hello""");
        end if;
        delete(message);
      elsif run("Test that an actor can poll for incoming messages") then
        receive(net, self, message, receive_status, 0 ns);
        check(receive_status = timeout, "Expected timeout");
        check(message = null, "Expected no message");
        send(net, self, self, "hello again", send_status);
        check(send_status = ok, "Expected send to succeed");
        receive(net, self, message, receive_status, 0 ns);
        if check(receive_status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello again", "Expected ""hello again""");
          check(message.sender = self, "Expected message from myself");
        end if;
        delete(message);
      elsif run("Test that sending to a non-existing actor results in an error code") then
        actor_to_destroy := create("actor to destroy");
        actor_to_destroy_copy := actor_to_destroy;
        destroy(actor_to_destroy, actor_destroy_status);
        send(net, actor_to_destroy_copy, "hello void", send_status);
        check(send_status = unknown_receiver_error, "Expected send to fail due to unknown receiver");
        send(net, null_actor_c, "hello void", send_status);
        check(send_status = unknown_receiver_error, "Expected send to fail due to unknown receiver");
      elsif run("Test that an actor can send to an actor with deferred creation") then
        deferred_actor := find("deferred actor");
        send(net, deferred_actor, "hello actor to be created", send_status);
        check(send_status = ok, "Expected send to succeed");
        deferred_actor := create("deferred actor");
        receive(net, deferred_actor, message, receive_status);
        if check(receive_status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello actor to be created", "Expected ""hello actor to be created""");
        end if;
        delete(message);
      elsif run("Test that receiving from an actor with deferred creation results in an error code") then
        deferred_actor := find("deferred actor");
        receive(net, deferred_actor, message, receive_status);
        check(receive_status = deferred_receiver_error, "Not allowed to send to a deferred actor");
      elsif run("Test that empty messages can be sent") then
        send(net, self, "", send_status);
        check(send_status = ok, "Expected send to succeed");
        receive(net, self, message, receive_status);
        if check(receive_status = ok, "Expected no problems with receive") then
          check(message.payload.all = "", "Expected an empty message");
        end if;
        delete(message);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);
  
  receiver: process is
    variable self : actor_t;
    variable message : message_ptr_t;
    variable receive_status : receive_status_t;
  begin
    wait until start_receiver;
    self := create("receiver");
    wait_for_messages(net, self, receive_status);
    message := get_message(self);
    if check(message.payload.all = "hello world", "Expected ""hello world""") then
      hello_world_received <= true;
    end if;
    delete(message);
    wait;
  end process receiver;

  server: process is
    variable self : actor_t;
    variable message : message_ptr_t;
    variable send_status : send_status_t;
    variable receive_status : receive_status_t;
  begin
    wait until start_server;
    self := create("server");
    receive(net, self, message, receive_status);
    if check(message.payload.all = "request", "Expected ""request""") then
      send(net, message.sender, "request acknowledge", send_status);
      check(send_status = ok, "Expected send to succeed");
    end if;
    delete(message);
    wait;
  end process server;

end test_fixture;
