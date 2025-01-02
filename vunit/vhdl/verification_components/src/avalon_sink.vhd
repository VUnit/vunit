-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon-St Sink Verification Component
-- TODO:
-- - timeout error

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.avalon_stream_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.stream_slave_pkg.stream_pop_msg;

entity avalon_sink is
  generic (
    sink : avalon_sink_t);
  port (
    clk   : in std_logic;
    ready : out std_logic := '0';
    valid : in std_logic;
    sop   : in std_logic;
    eop   : in std_logic;
    data  : in std_logic_vector(data_length(sink)-1 downto 0)
  );
end entity;

architecture a of avalon_sink is
begin
  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'range));
  begin
    receive(net, sink.p_actor, msg);
    msg_type := message_type(msg);

    if msg_type = stream_pop_msg or msg_type = pop_avalon_stream_msg then
      -- Loop till got valid data
      loop
        while rnd.Uniform(0.0, 1.0) > sink.ready_high_probability loop
          wait until rising_edge(clk);
        end loop;
        ready <= '1';
        wait until ready = '1' and rising_edge(clk);
        if valid = '1' then
          reply_msg := new_msg;
          if msg_type = pop_avalon_stream_msg then
            avalon_stream_transaction.data := data;
            if sop = '1' then
                avalon_stream_transaction.sop := true;
            else
                avalon_stream_transaction.sop := false;
            end if;
            if eop = '1' then
                avalon_stream_transaction.eop := true;
            else
                avalon_stream_transaction.eop := false;
            end if;
            push_avalon_stream_transaction(reply_msg, avalon_stream_transaction);
          else
            push_std_ulogic_vector(reply_msg, data);
          end if;
          reply(net, msg, reply_msg);
          ready <= '0';
          exit;
        end if;
        ready <= '0';
      end loop;

    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

end architecture;
