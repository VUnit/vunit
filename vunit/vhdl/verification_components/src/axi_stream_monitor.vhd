-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.axi_stream_pkg.all;
use work.com_pkg.net;
use work.com_pkg.publish;
use work.com_types_pkg.msg_t;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.string_ops.all;

entity axi_stream_monitor is
  generic (
    monitor : axi_stream_monitor_t);
  port (
    aclk   : in std_logic;
    tvalid : in std_logic;
    tready : in std_logic := '1';
    tdata  : in std_logic_vector(data_length(monitor) - 1 downto 0);
    tlast  : in std_logic := '1';
    tkeep  : in std_logic_vector(data_length(monitor)/8-1 downto 0) := (others => '1');
    tstrb  : in std_logic_vector(data_length(monitor)/8-1 downto 0) := (others => 'U');
    tid    : in std_logic_vector(id_length(monitor)-1 downto 0) := (others => '0');
    tdest  : in std_logic_vector(dest_length(monitor)-1 downto 0) := (others => '0');
    tuser  : in std_logic_vector(user_length(monitor)-1 downto 0) := (others => '0')
  );
end entity;

architecture a of axi_stream_monitor is
begin
  main : process
    variable msg : msg_t;
    variable axi_stream_transaction : axi_stream_transaction_t(
      tdata(tdata'range),
      tkeep(tkeep'range),
      tstrb(tstrb'range),
      tid(tid'range),
      tdest(tdest'range),
      tuser(tuser'range)
    );
    variable tstrb_resolved : std_logic_vector(tstrb'range);
  begin
    wait until (tvalid and tready) = '1' and rising_edge(aclk);

    if is_visible(monitor.p_logger, debug) then
      debug(monitor.p_logger, "tdata: " & to_nibble_string(tdata) & " (" & to_integer_string(tdata) & ")" & ", tlast: " & to_string(tlast));
    end if;

    tstrb_resolved := tkeep when is_u(tstrb) else tstrb;
    axi_stream_transaction := (
      tdata => tdata,
      tlast => tlast = '1',
      tkeep => tkeep,
      tstrb => tstrb_resolved,
      tid   => tid,
      tdest => tdest,
      tuser => tuser
    );

    msg := new_axi_stream_transaction_msg(axi_stream_transaction);
    publish(net, monitor.p_actor, msg);
  end process;

  axi_stream_protocol_checker_generate : if monitor.p_protocol_checker /= null_axi_stream_protocol_checker generate
    axi_stream_protocol_checker_inst: entity work.axi_stream_protocol_checker
      generic map (
        protocol_checker => monitor.p_protocol_checker)
      port map (
        aclk     => aclk,
        areset_n => open,
        tvalid   => tvalid,
        tready   => tready,
        tdata    => tdata,
        tlast    => tlast,
        tkeep    => tkeep,
        tstrb    => tstrb, -- Resolves unconnected signal internally
        tid      => tid,
        tdest    => tdest,
        tuser    => tuser
      );
  end generate axi_stream_protocol_checker_generate;

end architecture;
