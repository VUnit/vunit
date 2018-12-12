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
    master                 : axi_stream_master_t;
    drive_invalid          : boolean   := true;
    drive_invalid_val      : std_logic := 'X';
    drive_invalid_val_user : std_logic := '0'
  );
  port (
    aclk         : in  std_logic;
    areset_in_n  : in  std_logic                                          := '1';
    areset_out_n : out std_logic                                          := '1';
    tvalid       : out std_logic                                          := '0';
    tready       : in  std_logic                                          := '1';
    tdata        : out std_logic_vector(data_length(master)-1 downto 0)   := (others => '0');
    tlast        : out std_logic                                          := '0';
    tkeep        : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '0');
    tstrb        : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '0');
    tid          : out std_logic_vector(id_length(master)-1 downto 0)     := (others => '0');
    tdest        : out std_logic_vector(dest_length(master)-1 downto 0)   := (others => '0');
    tuser        : out std_logic_vector(user_length(master)-1 downto 0)   := (others => '0')
  );
end entity;

architecture a of axi_stream_master is

   signal notify_bus_process_done : std_logic := '0';
   constant message_queue         : queue_t   := new_queue;

begin

  main : process
    variable request_msg : msg_t;
    variable msg_type    : msg_type_t;
  begin
    receive(net, master.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
      push(message_queue, request_msg);
    elsif msg_type = axi_stream_reset_msg then
      push(message_queue, request_msg);
    elsif msg_type = wait_for_time_msg then
      push(message_queue, request_msg);
    elsif msg_type = wait_until_idle_msg then
      wait on notify_bus_process_done until is_empty(message_queue);
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  bus_process : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable reset_cycles : positive := 1;
  begin
    if drive_invalid then
      tdata <= (others => drive_invalid_val);
      tkeep <= (others => drive_invalid_val);
      tstrb <= (others => drive_invalid_val);
      tid   <= (others => drive_invalid_val);
      tdest <= (others => drive_invalid_val);
      tuser <= (others => drive_invalid_val_user);
    end if;

    -- Wait for messages to arrive on the queue, posted by the process above
    wait until rising_edge(aclk) and (not is_empty(message_queue) or areset_in_n = '0');

    if (areset_in_n = '0') then
      tvalid <= '0';
    else
      while not is_empty(message_queue) loop
        msg := pop(message_queue);
        msg_type := message_type(msg);

        if msg_type = wait_for_time_msg then
          handle_sync_message(net, msg_type, msg);
          -- Re-align with the clock when a wait for time message was handled, because this breaks edge alignment.
          wait until rising_edge(aclk);
        elsif msg_type = axi_stream_reset_msg then
          reset_cycles := pop(msg);
          areset_out_n <= '0';
          tvalid       <= '0';
          for I in 0 to reset_cycles - 1 loop
            wait until rising_edge(aclk);
          end loop;
          areset_out_n <= '1';

        elsif msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
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
            tid   <= (others => '0');
            tdest <= (others => '0');
            tuser <= (others => '0');
          end if;
          wait until ((tvalid and tready) = '1' or areset_in_n = '0') and rising_edge(aclk);
          tvalid <= '0';
          tlast <= '0';
        else
          unexpected_msg_type(msg_type);
        end if;

        delete(msg);
      end loop;

      notify_bus_process_done <= '1';
      wait until notify_bus_process_done = '1';
      notify_bus_process_done <= '0';
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
        areset_n => areset_in_n,
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