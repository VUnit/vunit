-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bus_master_pkg.all;
use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.memory_pkg.all;

entity bus2memory is
  generic (
    bus_handle : bus_master_t;
    memory : memory_t);
end entity;

architecture a of bus2memory is
  constant my_memory : memory_t := to_vc_interface(memory);
begin
  main : process
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable address : std_logic_vector(address_length(bus_handle)-1 downto 0);
    variable byte_enable : std_logic_vector(byte_enable_length(bus_handle)-1 downto 0);
    variable data  : std_logic_vector(data_length(bus_handle)-1 downto 0);
    constant blen : natural := byte_length(bus_handle);
  begin
    while true loop
      receive(net, bus_handle.p_actor, request_msg);
      msg_type := message_type(request_msg);

      if msg_type = bus_read_msg then
        address := pop_std_ulogic_vector(request_msg);
        data := read_word(my_memory, to_integer(unsigned(address)), bytes_per_word => data'length/8);
        reply_msg := new_msg;
        push_std_ulogic_vector(reply_msg, data);
        reply(net, request_msg, reply_msg);

      elsif msg_type = bus_write_msg then
        address := pop_std_ulogic_vector(request_msg);
        data := pop_std_ulogic_vector(request_msg);
        byte_enable := pop_std_ulogic_vector(request_msg);

        for i in byte_enable'range loop
          -- @TODO byte_enable on memory_t?
          if byte_enable(i) = '1' then
            write_word(my_memory, to_integer(unsigned(address))+i, data(blen*(i+1)-1 downto blen*i));
          end if;
        end loop;
      else
        unexpected_msg_type(msg_type);
      end if;
    end loop;
  end process;

end architecture;
