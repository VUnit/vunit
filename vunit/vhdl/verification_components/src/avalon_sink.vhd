-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon-St Sink Verification Component
-- TODO:
-- - timeout error

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

context work.vunit_context;
context work.com_context;
use work.stream_slave_pkg.all;
use work.avalon_stream_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity avalon_sink is
  generic (
    sink : avalon_sink_t);
  port (
    clk   : in std_logic;
    ready : out std_logic := '0';
    valid : in std_logic;
    sop   : in std_logic;
    eop   : in std_logic;
    data  : in std_logic_vector(data_length(sink)-1 downto 0);
    empty : in std_logic_vector(empty_length(sink)-1 downto 0)
  );
end entity;

architecture a of avalon_sink is
  constant data_queue : queue_t := new_queue;
begin
  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'range));
  begin
    if is_empty(data_queue) then
      wait until rising_edge(clk);
    else
      receive(net, sink.p_actor, msg);
      msg_type := message_type(msg);

      if msg_type = stream_pop_msg or msg_type = pop_avalon_stream_msg then
        reply_msg := new_msg;
        pop_avalon_stream_transaction(data_queue, avalon_stream_transaction);
          if msg_type = pop_avalon_stream_msg then
            push_avalon_stream_transaction(reply_msg, avalon_stream_transaction);
          else
            push_std_ulogic_vector(reply_msg, avalon_stream_transaction.data);
          end if;
          reply(net, msg, reply_msg);
      else
        unexpected_msg_type(msg_type);
      end if;
    end if;

  end process;

  data_handle : process
    variable rnd : RandomPType;
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'range));
  begin
    while rnd.Uniform(0.0, 1.0) > sink.ready_high_probability loop
      wait until rising_edge(clk);
    end loop;
    ready <= '1';
    wait until (valid and ready) = '1' and rising_edge(clk);
    avalon_stream_transaction.data := data;
    avalon_stream_transaction.sop := ?? sop;
    avalon_stream_transaction.eop := ?? eop;
    avalon_stream_transaction.empty := to_integer(empty);
    push_avalon_stream_transaction(data_queue, avalon_stream_transaction);
    ready <= '0';
  end process;

end architecture;
