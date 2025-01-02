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
use work.queue_pkg.all;
use work.stream_slave_pkg.stream_pop_msg;
use work.uart_pkg.all;

entity uart_slave is
  generic (
    uart : uart_slave_t);
  port (
    rx : in std_logic);
end entity;

architecture a of uart_slave is
  signal baud_rate : natural := uart.p_baud_rate;
  signal local_event : std_logic := '0';
  constant data_queue : queue_t := new_queue;
begin

  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, uart.p_actor, msg);
    msg_type := message_type(msg);

    if msg_type = uart_set_baud_rate_msg then
      baud_rate <= pop(msg);

    elsif msg_type = stream_pop_msg then
      reply_msg := new_msg;
      if not (length(data_queue) > 0) then
        wait on local_event until length(data_queue) > 0;
      end if;
      push_std_ulogic_vector(reply_msg, pop_std_ulogic_vector(data_queue));
      push_boolean(reply_msg, false);
      reply(net, msg, reply_msg);

    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

  recv : process
    procedure uart_recv(variable data : out std_logic_vector;
                        signal rx : in std_logic;
                        baud_rate : integer) is
      constant time_per_bit : time := (10**9 / baud_rate) * 1 ns;
      constant time_per_half_bit : time := (10**9 / (2*baud_rate)) * 1 ns;
    begin
      wait for time_per_half_bit; -- middle of start bit
      assert rx = not uart.p_idle_state;
      wait for time_per_bit; -- skip start bit

      for i in 0 to data'length-1 loop
        data(i) := rx;
        wait for time_per_bit;
      end loop;

      assert rx = uart.p_idle_state;
    end procedure;

    variable data : std_logic_vector(uart.p_data_length-1 downto 0);
  begin
    wait on rx until rx = not uart.p_idle_state;
    uart_recv(data, rx, baud_rate);
    push_std_ulogic_vector(data_queue, data);
    local_event <= '1';
    wait for 0 ns;
    local_event <= '0';
    wait for 0 ns;
  end process;

end architecture;
