-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.data_types_context;
context work.com_context;
use work.signal_driver_pkg.all;
use work.sync_pkg.all;

entity std_logic_driver is
  generic (
    signal_driver : signal_driver_t);
  port(
    clk   : in  std_logic;
    value : out std_logic_vector := signal_driver.initial
    );
end entity std_logic_driver;

architecture vc of std_logic_driver is
  constant internal_actor : actor_t := new_actor(vc'instance_name);
begin

  main : process is
    variable request_msg  : msg_t;
    variable reply_msg    : msg_t;
    variable internal_msg : msg_t;
    variable msg_type     : msg_type_t;
  begin
    receive(net, signal_driver.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = drive_msg then
      internal_msg := new_msg;
      push_std_ulogic_vector(internal_msg, pop_std_ulogic_vector(request_msg));
      send(net, internal_actor, internal_msg);

    elsif msg_type = wait_until_idle_msg then
      while has_message(internal_actor) loop
        wait until rising_edge(clk);
      end loop;

      reply_msg := new_msg(wait_until_idle_reply_msg);
      reply(net, request_msg, reply_msg);

    else
      unexpected_msg_type(msg_type, signal_driver.p_logger);
    end if;

    delete(request_msg);
  end process;

  driver : process is
    variable msg : msg_t;
  begin
    receive(net, internal_actor, msg);
    if clk'last_event > 0 ps then
      wait until rising_edge(clk);
    end if;
    value <= pop_std_ulogic_vector(msg);
    wait until rising_edge(clk);
  end process;

end architecture vc;
