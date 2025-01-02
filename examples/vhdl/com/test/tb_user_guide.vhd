-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

library lib;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.memory_bfm_pkg;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_user_guide is
  generic (
    runner_cfg : string);
end entity tb_user_guide;

architecture a of tb_user_guide is
  signal clk           : std_logic := '0';
  signal op_a, op_b    : unsigned(7 downto 0);
  signal sum           : unsigned(8 downto 0);
  signal dv_in, dv_out : std_logic := '0';

  constant driver         : actor_t             := new_actor("driver");
  constant monitor        : actor_t             := new_actor("monitor");
  constant master_channel : actor_t             := new_actor("driver channel");
  constant slave_channel  : actor_t             := new_actor("monitor channel");
  constant add_msg        : msg_type_t          := new_msg_type("add");
  constant sum_msg        : msg_type_t          := new_msg_type("sum");
  constant my_receiver    : actor_t             := new_actor("my receiver");
  constant test_sequencer : actor_t             := new_actor("test sequencer");
  constant channels       : actor_vec_t(1 to 2) := (new_actor("channel 1"), new_actor("channel 2"));
  constant clk_period     : time                := 10 ns;
begin
  test_runner : process
    variable msg, request_msg, reply_msg : msg_t;
    variable rnd                         : RandomPType;
    constant found_receiver              : actor_t                      := find("my receiver");
    constant my_integer                  : integer                      := 17;
    constant my_unsigned_address         : unsigned(7 downto 0)         := x"80";
    constant my_natural_address          : natural                      := 17;
    constant my_std_logic_vector_data    : std_logic_vector(7 downto 0) := x"21";
    variable data                        : std_logic_vector(7 downto 0);
    variable future                      : msg_t;
    constant sending_actor               : actor_t                      := new_actor("Sending actor");
    variable status                      : com_status_t;
    variable start                       : time;
    constant my_actor                    : actor_t                      := new_actor("My actor");
    variable msg_type                    : msg_type_t;
    variable mailbox_state               : mailbox_state_t;
    variable actor_state                 : actor_state_t;
    variable messenger_state             : messenger_state_t;
  begin
    test_runner_setup(runner, runner_cfg);
    show(display_handler, pass);

    while test_suite loop
      if run("Test sending a message to a known actor") then
        msg := new_msg;
        push_string(msg, "10101010");
        push(msg, my_integer);
        send(net, my_receiver, msg);

      elsif run("Test sending a message to a found actor") then
        msg := new_msg;
        push_string(msg, "10101010");
        push(msg, my_integer);
        send(net, found_receiver, msg);

      elsif run("Test sending messages with a message type with a name identical to another message type") then
        msg := new_msg(memory_bfm_pkg.write_msg);
        push(msg, my_unsigned_address);
        push(msg, my_std_logic_vector_data);
        send(net, memory_bfm_pkg.actor, msg);

      elsif run("Test encapsulating message passing details in transaction procedures") then
        memory_bfm_pkg.write(net, address => x"80", data => x"21");

      elsif run("Test requesting information") then
        memory_bfm_pkg.write(net, address => x"80", data => x"21");
        request_msg := new_msg(memory_bfm_pkg.read_msg);
        push(request_msg, unsigned'(x"80"));
        request(net, memory_bfm_pkg.actor, request_msg, reply_msg);
        msg_type    := message_type(reply_msg);
        data        := pop(reply_msg);
        check_equal(data, std_logic_vector'(x"21"));

      elsif run("Test sending/receiving a reply") then
        memory_bfm_pkg.write(net, address => x"80", data => x"21");
        memory_bfm_pkg.read(net, address  => x"80", data => data);
        check_equal(data, std_logic_vector'(x"21"));

      elsif run("Test blocking and non-blocking transactions") then
        memory_bfm_pkg.write(net, address             => x"80", data => x"21");
        memory_bfm_pkg.write(net, address             => x"84", data => x"17");
        memory_bfm_pkg.non_blocking_read(net, address => x"80", future => future);
        memory_bfm_pkg.blocking_read(net, address     => x"84", data => data);
        check_equal(data, std_logic_vector'(x"17"));
        memory_bfm_pkg.get(net, future, data);
        check_equal(data, std_logic_vector'(x"21"));

      elsif run("Test blocking on acknowledge") then
        start := now;
        memory_bfm_pkg.write(net, address          => x"80", data => x"21");
        check_equal(now, start);
        start := now;
        memory_bfm_pkg.blocking_write(net, address => x"84", data => x"17");
        check(now > start);

      elsif run("Synchronize with a rendezvous") then
        memory_bfm_pkg.write(net, address => x"80", data => x"21");
        info("Synchronizing at " & to_string(now));
        wait_until_idle(net, memory_bfm_pkg.actor);
        info("Synchronized at " & to_string(now));

      elsif run("Test timeout") then
        wait_for_message(net, my_actor, status, timeout => 10 ns);
        check(status = timeout, result("for status = timeout when no messages have been sent"));
        check(not has_message(my_actor), result("for no presence of messages when no messages have been sent"));

        msg := new_msg;
        push_string(msg, "hello");
        send(net, my_actor, msg);

        wait_for_message(net, my_actor, status, timeout => 10 ns);
        check(status = ok, result("for status = ok when a message has been sent"));
        check(has_message(my_actor), result("for presence of messages when a message has been sent"));
        get_message(net, my_actor, msg);
        check_equal(pop_string(msg), "hello");

      elsif run("Test actor with multiple channels (actors)") then
        msg := new_msg;
        push_string(msg, "alpha");
        send(net, channels(1), msg);
        wait for 10 ns;
        msg := new_msg;
        push_string(msg, "beta");
        send(net, channels(2), msg);

      elsif run("Signing messages") then
        memory_bfm_pkg.write(net, address             => x"80", data => x"21");
        memory_bfm_pkg.non_blocking_read(net, address => x"80", future => future);

        wait_for_message(net, sending_actor, status, timeout => 1 ns);
        check(status = timeout, "The read request reply shouldn't be able to find it's way to the sender's inbox");

        memory_bfm_pkg.write(net, address        => x"84", data => x"17");
        msg  := new_msg(memory_bfm_pkg.read_msg, sending_actor);
        push(msg, unsigned'(x"84"));
        send(net, memory_bfm_pkg.actor, msg);
        receive(net, sending_actor, msg, timeout => 100 ns);
        msg_type := message_type(msg);
        data := pop(msg);
        check_equal(data, std_logic_vector'(x"17"));

      elsif run("Test publisher/subscriber") then
        for i in 1 to 10 loop
          msg := new_msg(add_msg);
          push(msg, rnd.RandInt(0, 255));
          push(msg, rnd.RandInt(0, 255));
          send(net, driver, msg);
          wait_for_time(net, driver, rnd.RandTime(0 ns, 10 * clk_period));
        end loop;
        wait_until_idle(net, master_channel);

      elsif run("Test debugging features") then
        show(com_logger, display_handler, trace);
        show(display_handler, debug);

        msg         := new_msg(memory_bfm_pkg.write_msg);
        push(msg, my_unsigned_address);
        push(msg, my_std_logic_vector_data);
        send(net, memory_bfm_pkg.actor, msg);
        request_msg := new_msg(memory_bfm_pkg.read_msg, test_sequencer);
        push(request_msg, unsigned'(x"80"));
        send(net, memory_bfm_pkg.actor, request_msg);
        wait for 30 ns;
        receive_reply(net, request_msg, reply_msg);

        memory_bfm_pkg.write(net, address             => x"80", data => x"17");
        memory_bfm_pkg.write(net, address             => x"84", data => x"21");
        memory_bfm_pkg.non_blocking_read(net, address => x"80", future => future);

        mailbox_state := get_mailbox_state(memory_bfm_pkg.actor, inbox);
        debug(get_mailbox_state_string(memory_bfm_pkg.actor, inbox));

        memory_bfm_pkg.get(net, future, data);

        for i in 1 to 3 loop
          msg := new_msg(add_msg);
          push(msg, rnd.RandInt(0, 255));
          push(msg, rnd.RandInt(0, 255));
          send(net, driver, msg);
        end loop;
        actor_state := get_actor_state(driver);
        debug(get_actor_state_string(driver));

        messenger_state := get_messenger_state;
        debug(get_messenger_state_string);
      end if;
    end loop;

    wait for 100 ns;
    test_runner_cleanup(runner);
    wait;
  end process;

  my_receiver_process : process
    variable msg        : msg_t;
    variable my_integer : integer;
  begin
    receive(net, my_receiver, msg);
    check_equal(pop_string(msg), "10101010");
    my_integer := pop(msg);
    check_equal(my_integer, 17);
  end process;

  multiple_channel_process : process is
    variable status : com_status_t;
    variable msg    : msg_t;
  begin
    wait_for_message(net, channels, status);
    if status = ok then
      for i in channels'range loop
        if has_message(channels(i)) then
          get_message(net, channels(i), msg);
          info("Received " & pop_string(msg) & " on " & name(channels(i)));
        end if;
      end loop;
    end if;
  end process;

  memory_bfm : entity work.memory_bfm;

  test_runner_watchdog(runner, 500 ms);

  clk <= not clk after clk_period / 2;

  driver_process : process is
    variable request_msg : msg_t;
    variable msg_type    : msg_type_t;
  begin
    receive(net, driver, request_msg);
    msg_type := message_type(request_msg);

    handle_wait_for_time(net, msg_type, request_msg);

    if msg_type = add_msg then
      op_a  <= to_unsigned(pop(request_msg), op_a);
      op_b  <= to_unsigned(pop(request_msg), op_a);
      dv_in <= '1';
      wait until rising_edge(clk);
      dv_in <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  monitor_process : process is
    variable msg : msg_t;
  begin
    wait until rising_edge(clk) and (dv_out = '1');
    msg := new_msg(sum_msg);
    push(msg, to_integer(sum));
    publish(net, monitor, msg);
  end process;

  scoreboard_process : process is
    variable master_msg, slave_msg : msg_t;
    variable msg_type              : msg_type_t;

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

      if receiver(master_msg) = master_channel then
        handle_wait_until_idle(net, msg_type, master_msg);
      end if;

      if msg_type = add_msg then
        receive(net, slave_channel, slave_msg);

        if message_type(slave_msg) = sum_msg then
          do_model_check(master_msg, slave_msg);
        end if;
      end if;
    end loop;
  end process;

  adder : entity lib.adder
    port map(
      clk    => clk,
      op_a   => op_a,
      op_b   => op_b,
      dv_in  => dv_in,
      sum    => sum,
      dv_out => dv_out
      );

end;
