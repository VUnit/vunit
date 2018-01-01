library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.memory_bfm_pkg.all;

entity memory_bfm is
end entity memory_bfm;

architecture a of memory_bfm is
begin
  message_handler : process is
    variable request_msg, reply_msg : msg_t;
    variable msg_type               : msg_type_t;
    variable address                : unsigned(7 downto 0);
    variable data                   : std_logic_vector(7 downto 0);
    variable memory                 : integer_vector(0 to 255) := (others => 0);

    procedure emulate_memory_access_delay is
    begin
      wait for 10 ns;
    end procedure;
  begin
    receive(net, actor, request_msg);
    msg_type := pop(request_msg);

    handle_sync_message(net, msg_type, request_msg);

    if msg_type = write_msg then
      address                     := pop(request_msg);
      data                        := pop(request_msg);
      emulate_memory_access_delay;
      memory(to_integer(address)) := to_integer(data);

    elsif msg_type = write_with_acknowledge_msg then
      address                     := pop(request_msg);
      data                        := pop(request_msg);
      emulate_memory_access_delay;
      memory(to_integer(address)) := to_integer(data);
      acknowledge(net, request_msg, true);

    elsif msg_type = read_msg then
      address   := pop(request_msg);
      emulate_memory_access_delay;
      data      := to_std_logic_vector(memory(to_integer(address)), 8);
      reply_msg := new_msg;
      push(reply_msg, data);
      reply(net, request_msg, reply_msg);

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;
end architecture;
