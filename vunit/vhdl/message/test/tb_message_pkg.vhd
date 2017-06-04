-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.message_pkg.all;
use work.queue_pkg.all;
use work.integer_vector_ptr_pkg.all;

entity tb_message is
  generic (runner_cfg : string);
end entity;

architecture a of tb_message is
  signal start : boolean := false;
  signal support_done : boolean := false;
  constant inbox : inbox_t := new_inbox;
  constant inboxes : inbox_vec_t := (new_inbox, new_inbox);

  constant large_inbox_size : natural := 512;
begin

  main : process
    variable msg : msg_t;
    variable reply : reply_t;
  begin
    test_runner_setup(runner, runner_cfg);
    logger_init(display_format => verbose);

    if run("Send and recv") then
      start <= true;
      msg := allocate;
      push(msg.data, 77);
      push(msg.data, 88);
      send(event, inbox, msg);
      assert msg.data = null_queue report "Ownership should be transfered and data be null here";

    elsif run("Send and reply") then
      start <= true;
      msg := allocate;
      push(msg.data, 77);
      send(event, inbox, msg, reply);
      assert msg.data = null_queue report "Ownership should be transfered and data be null here";
      assert reply.data = null_queue report "Ownership should be transfered and reply be null here";
      recv_reply(event, reply);
      assert reply.data /= null_queue report "Valid reply should be given here";
      check_equal(pop(reply.data), 101, "reply 1");
      check_equal(pop(reply.data), 102, "reply 2");
      check_equal(pop(reply.data), 103, "reply 3");
      recycle(reply);
      assert reply = null_reply report "Reply should be null after recycle";

    elsif run("Send without recv") then
      start <= true;
      for i in 0 to 128 loop
        wait for 0 ns;
      end loop;

    elsif run("Recv without send") then
      start <= true;
      for i in 0 to 128 loop
        wait for 0 ns;
      end loop;

    elsif run("Multi inbox recieve") then
      start <= true;
      msg := allocate;
      push(msg.data, 11);
      send(event, inboxes(0), msg);

      msg := allocate;
      push(msg.data, 22);
      send(event, inboxes(1), msg);

    elsif run("Has backpressure") then
      start <= true;
      msg := allocate;
      push(msg.data, 71);
      send(event, inbox, msg);

      msg := allocate;
      push(msg.data, 72);
      send(event, inbox, msg);

      msg := allocate;
      push(msg.data, 73);
      send(event, inbox, msg);

    elsif run("Has inbox size") then
      set_size(inbox, large_inbox_size);
      check_equal(get_size(inbox), large_inbox_size);
      for i in 1 to large_inbox_size loop
        msg := allocate;
        push(msg.data, i);
        send(event, inbox, msg);
      end loop;

      start <= true;
    end if;

    while not support_done loop
      wait for 0 ns;
    end loop;
    test_runner_cleanup(runner);
  end process;

  support_process : process
    variable msg : msg_t;
    variable reply : reply_t;
  begin
    wait until start;

    -- @TODO test sending null reply is received as null reply
    if enabled("Send and recv") then
      recv(event, inbox, msg);
      check_equal(pop(msg.data), 77, "data 0");
      check_equal(pop(msg.data), 88, "data 1");
      recycle(msg);
      assert msg = null_msg report "Message should be null after recycle";
      support_done <= true;

    elsif enabled("Send and reply") then
      recv(event, inbox, msg, reply);
      check_equal(pop(msg.data), 77, "data 0");
      assert reply /= null_reply report "Excepted reply";
      push(reply.data, 101);
      push(reply.data, 102);
      push(reply.data, 103);
      send_reply(event, reply);
      assert reply = null_reply report "Ownership of reply is transfered";
      recycle(reply);
      support_done <= true;

    elsif enabled("Send without recv") then
      msg := allocate;
      send(event, inbox, msg);
      support_done <= true;
      msg := allocate;
      send(event, inbox, msg);
      assert false report "Should never happen";

    elsif enabled("Recv without send") then
      support_done <= true;
      recv(event, inbox, msg);
      recycle(msg);
      assert false report "Should never happen";

    elsif enabled("Multi inbox recieve") then
      recv(event, inboxes, msg);
      check_equal(pop(msg.data), 11, "data 0");
      recycle(msg);

      recv(event, inboxes, msg);
      check_equal(pop(msg.data), 22, "data 1");
      recycle(msg);
      support_done <= true;

    elsif enabled("Has backpressure") then
      for i in 0 to 128 loop
        wait for 0 ns;
      end loop;
      recv(event, inbox, msg);
      check_equal(pop(msg.data), 71, "data");
      recycle(msg);

      recv(event, inbox, msg);
      check_equal(pop(msg.data), 72, "data");
      recycle(msg);

      recv(event, inbox, msg);
      check_equal(pop(msg.data), 73, "data");
      recycle(msg);

      support_done <= true;
    elsif enabled("Has inbox size") then
      for i in 1 to large_inbox_size loop
        recv(event, inbox, msg);
        check_equal(pop(msg.data), i, "data: " & to_string(i));
        recycle(msg);
      end loop;
      support_done <= true;
    end if;

    wait;
  end process;

  watchdog : process
    constant max_num_delta : integer := 4000;
    variable num_delta : integer := 0;
  begin
    num_delta := num_delta + 1;
    assert num_delta < max_num_delta report "Took more than " & to_string(max_num_delta) & " delta cycles";
    wait for 0 ns;
  end process;


end architecture;
