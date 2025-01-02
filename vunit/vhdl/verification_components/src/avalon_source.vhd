-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon-St Source Verification Component

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.avalon_stream_pkg.all;
use work.com_pkg.receive;
use work.com_pkg.net;
use work.com_types_pkg.all;
use work.stream_master_pkg.stream_push_msg;
use work.sync_pkg.handle_sync_message;

entity avalon_source is
  generic (
    source : avalon_source_t);
  port (
    clk   : in std_logic;
    ready : in std_logic;
    valid : out std_logic := '0';
    sop   : out std_logic := '0';
    eop   : out std_logic := '0';
    data  : out std_logic_vector(data_length(source)-1 downto 0) := (others => '0')
  );
end entity;

architecture a of avalon_source is
begin
  main : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'range));
  begin
    receive(net, source.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg or msg_type = push_avalon_stream_msg then
      while rnd.Uniform(0.0, 1.0) > source.valid_high_probability loop
        wait until rising_edge(clk);
      end loop;
      valid <= '1';
      if msg_type = push_avalon_stream_msg then
        pop_avalon_stream_transaction(msg, avalon_stream_transaction);
        data <= avalon_stream_transaction.data;
        if avalon_stream_transaction.sop then
          sop <= '1';
        else
          sop <= '0';
        end if;
        if avalon_stream_transaction.eop then
          eop <= '1';
        else
          eop <= '0';
        end if;
      else
        data <= pop_std_ulogic_vector(msg);
        sop <= '0';
        eop <= '0';
      end if;
      wait until (valid and ready) = '1' and rising_edge(clk);
      valid <= '0';
      sop   <= '0';
      eop   <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

end architecture;
