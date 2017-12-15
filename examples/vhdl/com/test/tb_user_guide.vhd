library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bfm1_pkg;
use work.bfm2_pkg;

entity tb_user_guide is
  generic (
    runner_cfg : string);
end entity tb_user_guide;

architecture a of tb_user_guide is
  constant receiver : actor_t := new_actor("my receiver");
  constant channels : actor_vec_t(1 to 2) := (new_actor("channel 1"), new_actor("channel 2"));
begin
  test_runner : process
    variable msg, request_msg, reply_msg : msg_t;
    constant found_receiver : actor_t := find("my receiver");
    constant my_integer : integer := 17;
    constant my_unsigned_address : unsigned(7 downto 0) := x"80";
    constant my_natural_address : natural := 17;
    constant my_std_logic_vector_data : std_logic_vector(7 downto 0) := x"21";
    variable data : std_logic_vector(7 downto 0);
    variable future : msg_t;
    constant sending_actor : actor_t := new_actor("Sending actor");
    variable status : com_status_t;
    variable start : time;
    constant my_actor : actor_t := new_actor("My actor");
  begin
    test_runner_setup(runner, runner_cfg);
    set_log_level(display_handler, pass);

    while test_suite loop
      if run("Test sending a message to a known actor") then
        msg := new_msg;
        push_string(msg, "10101010");
        push(msg, my_integer);
        send(net, receiver, msg);
      elsif run("Test sending a message to a found actor") then
        msg := new_msg;
        push_string(msg, "10101010");
        push(msg, my_integer);
        send(net, found_receiver, msg);
      elsif run("Test sending messages with a message type with a name identical to another message type") then
        msg := new_msg;
        push(msg, bfm1_pkg.write_msg);
        push(msg, my_unsigned_address);
        push(msg, my_std_logic_vector_data);
        send(net, bfm1_pkg.actor, msg);
      elsif run("Test encapsulating message passing details in transaction procedures") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
      elsif run("Test requesting information") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
        request_msg := new_msg;
        push(request_msg, bfm1_pkg.read_msg);
        push(request_msg, unsigned'(x"80"));
        request(net, bfm1_pkg.actor, request_msg, reply_msg);
        data := pop(reply_msg);
        check_equal(data, std_logic_vector'(x"21"));
      elsif run("Test sending/receiving a reply") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
        bfm1_pkg.read(net, address => x"80", data => data);
        check_equal(data, std_logic_vector'(x"21"));
      elsif run("Test blocking and non-blocking transactions") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
        bfm1_pkg.write(net, address => x"84", data => x"17");
        bfm1_pkg.non_blocking_read(net, address => x"80", future => future);
        bfm1_pkg.blocking_read(net, address => x"84", data => data);
        check_equal(data, std_logic_vector'(x"17"));
        bfm1_pkg.get(net, future, data);
        check_equal(data, std_logic_vector'(x"21"));
      elsif run("Test blocking on acknowledge") then
        start := now;
        bfm1_pkg.write(net, address => x"80", data => x"21");
        check_equal(now, start);
        start := now;
        bfm1_pkg.blocking_write(net, address => x"84", data => x"17");
        check(now > start);
      elsif run("Synchronize with a rendezvous") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
        info("Synchronizing at " & to_string(now));
        wait_until_idle(net, bfm1_pkg.actor);
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
        check_equal(pop_string(get_message(my_actor)), "hello");
      elsif run("Test actor with multiple channels (actors)") then
        msg := new_msg;
        push_string(msg, "alpha");
        send(net, channels(1), msg);
        wait for 10 ns;
        msg := new_msg;
        push_string(msg, "beta");
        send(net, channels(2), msg);
      elsif run("Signing messages") then
        bfm1_pkg.write(net, address => x"80", data => x"21");
        bfm1_pkg.non_blocking_read(net, address => x"80", future => future);

        wait_for_message(net, sending_actor, status, timeout => 1 ns);
        check(status = timeout, "The read request reply shouldn't be able to find it's way to the sender's inbox");

        bfm1_pkg.write(net, address => x"84", data => x"17");
        msg := new_msg(sending_actor);
        push(msg, bfm1_pkg.read_msg);
        push(msg, unsigned'(x"84"));
        send(net, bfm1_pkg.actor, msg);
        receive(net, sending_actor, msg, timeout => 100 ns);
        data := pop(msg);
        check_equal(data, std_logic_vector'(x"17"));

      end if;
    end loop;

    wait for 100 ns;
    test_runner_cleanup(runner);
    wait;
  end process;

  receiver_process : process
    variable msg : msg_t;
    variable my_integer : integer;
  begin
    receive(net, receiver, msg);
    check_equal(pop_string(msg), "10101010");
    my_integer := pop(msg);
    check_equal(my_integer, 17);
  end process;

  multiple_channel_process: process is
    variable status : com_status_t;
  begin
    wait_for_message(net, channels, status);
    if status = ok then
      for i in channels'range loop
        if has_message(channels(i)) then
          info("Received " & pop_string(get_message(channels(i))) & " on " & name(channels(i)));
        end if;
      end loop;
    end if;
  end process;

  bfm1 : entity work.bfm1;

end;
