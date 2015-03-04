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
  signal hello_world_received : boolean := false;
begin
  test_runner : process
    variable actor_to_be_found, actor_with_deferred_creation, actor_to_destroy,
             actor_to_destroy_copy, actor_to_keep, actor, actor_duplicate,
             self, receiver, server: actor_t;
    variable actor_destroy_status : actor_destroy_status_t;
    variable n_actors : natural;
    variable send_status : send_status_t;
    variable msg : message_t;
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
        check(actor_destroy_status = destroy_ok, "Expected destroy status to be ok");
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
        receiver := find("receiver");
        send(net, receiver, "hello world", send_status);
        check(send_status = ok, "Expected send to succeed");
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");
      elsif run("Test that an actor can send a message in response to another message from an a priori unknown actor") then
        server := find("server");
        send(net, self, server, "request", send_status);
        check(send_status = ok, "Expected send to succeed");
        receive(self, msg);
        check(get_payload(msg) = "request acknowledge", "Expected ""request acknowledge""");
        check(get_status(msg) = received, "Bad receive status");
      --elsif run("Test that an actor can send a message to itself") then
      --elsif run("Test that an actor can poll for incoming messages") then
      --elsif run("Test that an actor timing out on reception receives a no message status") then
      --elsif run("Test that an actor can be synchronized with the reply of a previous request") then
      --elsif run("Test that sending to a non-existing actor results in an error code") then
      --elsif run("Test that an actor can send to an actor with deferred creation") then
      --elsif run("Test that receiving from an actor with deferred creation results in an error code") then
        
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);
  
  receiver: process is
    variable self : actor_t;
    variable msg : message_t;
  begin
    self := create("receiver");
    receive(self, msg);
    if check(get_payload(msg) = "hello world", "Expected ""hello world""") and
      check(get_status(msg) = received, "Bad receive status") then
      hello_world_received <= true;
    end if;
    wait;
  end process receiver;

  server: process is
    variable self, client : actor_t;
    variable msg : message_t;
    variable send_status : send_status_t;
  begin
    self := create("server");
    receive(self, msg);
    if check(get_payload(msg) = "request", "Expected ""request""") and
      check(get_status(msg) = received, "Bad receive status") then
      send(net, client, "request acknowledge", send_status);
      check(send_status = ok, "Expected send to succeed");
    end if;
    wait;
  end process server;

end test_fixture;
