-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.signal_checker_pkg.all;
use work.sync_pkg.wait_until_idle_msg;
use work.sync_pkg.wait_until_idle_reply_msg;

entity std_logic_checker is
  generic (
    signal_checker : signal_checker_t);
  port (
    value : in std_logic_vector);
end entity;


architecture a of std_logic_checker is
  constant expect_queue : queue_t := new_queue;
begin

  main : process
    variable request_msg : msg_t;
    variable reply_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, signal_checker.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = expect_msg then
      push_std_ulogic_vector(expect_queue, pop_std_ulogic_vector(request_msg));
      push_time(expect_queue, pop_time(request_msg));
      push_time(expect_queue, pop_time(request_msg));

    elsif msg_type = wait_until_idle_msg then

      while not is_empty(expect_queue) loop
        if value'event then
          wait for 0 ns;
        else
          wait on value;
        end if;
      end loop;

      reply_msg := new_msg(wait_until_idle_reply_msg);
      reply(net, request_msg, reply_msg);
    else
      unexpected_msg_type(msg_type);
    end if;

    delete(request_msg);
  end process;

  monitor : process
    variable expected_value : std_logic_vector(value'range);
    variable event_time, margin : delay_length;

    impure function margin_suffix return string is
    begin
      if margin = 0 ns then
        return "";
      else
        return " +- " & time'image(margin);
      end if;
    end;
  begin
    wait on value;
    if is_empty(expect_queue) then
      error(signal_checker.p_logger, "Unexpected event with value = " & to_string(value));
    else
      expected_value := pop_std_ulogic_vector(expect_queue);
      event_time := pop_time(expect_queue);
      margin := pop_time(expect_queue);

      if value /= expected_value then
        error(signal_checker.p_logger, "Got event with wrong value, got " & to_string(value) &
              " expected " & to_string(expected_value));

      elsif now < event_time - margin or now > event_time + margin then
        error(signal_checker.p_logger, "Got event at wrong time, occured at " & time'image(now) &
              " expected at " & time'image(event_time) & margin_suffix);

      else
        pass(signal_checker.p_logger, "Got expected event with value = " & to_string(value));
      end if;
    end if;
  end process;
end architecture;
