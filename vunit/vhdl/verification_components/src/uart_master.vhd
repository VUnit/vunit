-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.stream_master_pkg.stream_push_msg;
use work.sync_pkg.handle_sync_message;
use work.uart_pkg.all;

entity uart_master is
  generic (
    uart : uart_master_t
  );
  port (
    tx : out std_logic := uart.p_idle_state
  );
end entity uart_master;

architecture a of uart_master is
begin

  main : process
    procedure uart_send(data : std_logic_vector;
                        signal tx : out std_logic;
                        baud_rate  : integer;
                        parity     : natural
  ) is
      constant time_per_bit : time := (10**9 / baud_rate) * 1 ns;

      procedure send_bit(value : std_logic) is
      begin
        tx <= value;
        wait for time_per_bit;
      end procedure;

    begin
      debug("Sending " & to_string(data));
      send_bit(not uart.p_idle_state);
      for i in 0 to data'length-1 loop
        send_bit(data(i));
      end loop;

      if parity = 1 then
        send_bit(odd_parity(data));
      elsif parity = 2 then
        send_bit(even_parity(data));
	  end if;

      send_bit(uart.p_idle_state);
    end procedure;

    variable msg : msg_t;
    variable baud_rate : natural := uart.p_baud_rate;
    variable parity    : natural := uart.p_parity;
    variable msg_type : msg_type_t;
  begin
    receive(net, uart.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      uart_send(pop_std_ulogic_vector(msg), tx, baud_rate, parity);
    elsif msg_type = uart_set_baud_rate_msg then
      baud_rate := pop(msg);
    elsif msg_type = uart_set_parity_msg then
      parity := pop(msg);
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

end architecture;
