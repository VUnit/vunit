-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_master_pkg.all;
use work.axi_stream_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

entity axi_stream_master is
  generic (
    master : axi_stream_master_t;
    drive_invalid          : boolean   := true;
    drive_invalid_val      : std_logic := 'X';
    drive_invalid_val_user : std_logic := '0'
  );
  port (
    aclk   : in std_logic;
    tvalid : out std_logic                                          := '0';
    tready : in std_logic                                           := '1';
    tdata  : out std_logic_vector(data_length(master)-1 downto 0)   := (others => '0');
    tlast  : out std_logic                                          := '0';
    tkeep  : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '0');
    tstrb  : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '0');
    tid    : out std_logic_vector(id_length(master)-1 downto 0)     := (others => '0');
    tdest  : out std_logic_vector(dest_length(master)-1 downto 0)   := (others => '0');
    tuser  : out std_logic_vector(user_length(master)-1 downto 0)   := (others => '0')
  );
end entity;

architecture a of axi_stream_master is
begin
  main : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    if drive_invalid then
      tdata <= (others => drive_invalid_val);
      tkeep <= (others => drive_invalid_val);
      tstrb <= (others => drive_invalid_val);
      tid   <= (others => drive_invalid_val);
      tdest <= (others => drive_invalid_val);
      tuser <= (others => drive_invalid_val_user);
    end if;

    receive(net, master.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
      tvalid <= '1';
      tdata <= pop_std_ulogic_vector(msg);
      if msg_type = push_axi_stream_msg then
        tlast <= pop_std_ulogic(msg);
        tkeep <= pop_std_ulogic_vector(msg);
        tstrb <= pop_std_ulogic_vector(msg);
        tid <= pop_std_ulogic_vector(msg);
        tdest <= pop_std_ulogic_vector(msg);
        tuser <= pop_std_ulogic_vector(msg);
      else
        if pop_boolean(msg) then
          tlast <= '1';
        else
          tlast <= '0';
        end if;
        tkeep <= (others => '1');
        tstrb <= (others => '1');
        tid <= (others => '0');
        tdest <= (others => '0');
        tuser <= (others => '0');
      end if;
      wait until (tvalid and tready) = '1' and rising_edge(aclk);
      tvalid <= '0';
      tlast <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  axi_stream_monitor_generate : if master.p_monitor /= null_axi_stream_monitor generate
    axi_stream_monitor_inst : entity work.axi_stream_monitor
      generic map(
        monitor => master.p_monitor
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

  axi_stream_protocol_checker_generate : if master.p_protocol_checker /= null_axi_stream_protocol_checker generate
    axi_stream_protocol_checker_inst: entity work.axi_stream_protocol_checker
      generic map (
        protocol_checker => master.p_protocol_checker)
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
