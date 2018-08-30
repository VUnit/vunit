-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_slave_pkg.all;
use work.axi_stream_pkg.all;
use work.sync_pkg.all;

entity axi_stream_slave is
  generic (
    slave : axi_stream_slave_t);
  port (
    aclk   : in std_logic;
    tvalid : in std_logic;
    tready : out std_logic := '0';
    tdata  : in std_logic_vector(data_length(slave)-1 downto 0);
    tlast  : in std_logic                                         := '1';
    tkeep  : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tstrb  : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tid    : in std_logic_vector(id_length(slave)-1 downto 0)     := (others => '0');
    tdest  : in std_logic_vector(dest_length(slave)-1 downto 0)   := (others => '0');
    tuser  : in std_logic_vector(user_length(slave)-1 downto 0)   := (others => '0')
 );
end entity;

architecture a of axi_stream_slave is
begin
  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
    variable axi_stream_transaction : axi_stream_transaction_t(
      tdata(tdata'range),
      tkeep(tkeep'range),
      tstrb(tstrb'range),
      tid(tid'range),
      tdest(tdest'range),
      tuser(tuser'range)
    );
  begin
    receive(net, slave.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_pop_msg or msg_type = pop_axi_stream_msg then
      tready <= '1';
      wait until (tvalid and tready) = '1' and rising_edge(aclk);
      tready <= '0';

      axi_stream_transaction := (
        tdata => tdata,
        tlast => tlast = '1',
        tkeep => tkeep,
        tstrb => tstrb,
        tid   => tid,
        tdest => tdest,
        tuser => tuser
      );

      reply_msg := new_axi_stream_transaction_msg(axi_stream_transaction);
      reply(net, msg, reply_msg);

    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

  axi_stream_monitor_generate : if slave.p_monitor /= null_axi_stream_monitor generate
    axi_stream_monitor_inst : entity work.axi_stream_monitor
      generic map(
        monitor => slave.p_monitor
      )
      port map(
        aclk   => aclk,
        tvalid => tvalid,
        tready => tready,
        tdata  => tdata,
        tlast  => tlast,
        tkeep  => tkeep,
        tstrb  => tstrb,
        tid    => tid,
        tdest  => tdest,
        tuser  => tuser
      );
  end generate axi_stream_monitor_generate;

  axi_stream_protocol_checker_generate : if slave.p_protocol_checker /= null_axi_stream_protocol_checker generate
    axi_stream_protocol_checker_inst: entity work.axi_stream_protocol_checker
      generic map (
        protocol_checker => slave.p_protocol_checker)
      port map (
        aclk     => aclk,
        areset_n => open,
        tvalid   => tvalid,
        tready   => tready,
        tdata    => tdata,
        tlast    => tlast,
        tkeep    => tkeep,
        tstrb    => tstrb,
        tid      => tid,
        tdest    => tdest,
        tuser    => tuser
        );
  end generate axi_stream_protocol_checker_generate;

end architecture;
