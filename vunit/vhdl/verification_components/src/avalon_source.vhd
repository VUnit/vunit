-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon-St Source Verification Component
library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_master_pkg.all;
use work.avalon_stream_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity avalon_source is
  generic (
    source : avalon_source_t);
  port (
    clk : in std_logic;
    valid : out std_logic := '0';
    ready : in std_logic;
    data : out std_logic_vector(data_length(source)-1 downto 0) := (others => '0')
  );
end entity;

architecture a of avalon_source is
begin
  main : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
  begin
    receive(net, source.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      while rnd.Uniform(0.0, 1.0) > source.valid_high_probability loop
        wait until rising_edge(clk);
      end loop;
      valid <= '1';
      data <= pop_std_ulogic_vector(msg);
      wait until (valid and ready) = '1' and rising_edge(clk);
      valid <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

end architecture;
