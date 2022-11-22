-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_master_pkg.all;
use work.axi_stream_pkg.all;
use work.axi_stream_private_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

entity axi_stream_master is
  generic (
    master                 : axi_stream_master_t;
    drive_invalid          : boolean   := true;
    drive_invalid_val      : std_logic := 'X';
    drive_invalid_val_user : std_logic := '0'
  );
  port (
    aclk         : in  std_logic;
    areset_n     : in  std_logic                                          := '1';
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

  constant notify_request_msg      : msg_type_t := new_msg_type("notify request");
  constant message_queue           : queue_t    := new_queue;
  signal   notify_bus_process_done : std_logic  := '0';

  procedure drive_invalid_output(signal l_tdata : out std_logic_vector(data_length(master)-1 downto 0);
                                 signal l_tkeep : out std_logic_vector(data_length(master)/8-1 downto 0);
                                 signal l_tstrb : out std_logic_vector(data_length(master)/8-1 downto 0);
                                 signal l_tid   : out std_logic_vector(id_length(master)-1 downto 0);
                                 signal l_tdest : out std_logic_vector(dest_length(master)-1 downto 0);
                                 signal l_tuser : out std_logic_vector(user_length(master)-1 downto 0))
  is
  begin
    l_tdata <= (others => drive_invalid_val);
    l_tkeep <= (others => drive_invalid_val);
    l_tstrb <= (others => drive_invalid_val);
    l_tid   <= (others => drive_invalid_val);
    l_tdest <= (others => drive_invalid_val);
    l_tuser <= (others => drive_invalid_val_user);
  end procedure;

begin

  main : process
    variable request_msg : msg_t;
    variable notify_msg  : msg_t;
    variable msg_type    : msg_type_t;
  begin
    receive(net, master.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
      push(message_queue, request_msg);
    elsif msg_type = wait_for_time_msg then
      push(message_queue, request_msg);
    elsif msg_type = wait_until_idle_msg then
      notify_msg := new_msg(notify_request_msg);
      push(message_queue, notify_msg);
      wait on notify_bus_process_done until is_empty(message_queue);
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  bus_process : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name);
    loop
      if drive_invalid then
        drive_invalid_output(tdata, tkeep, tstrb, tid, tdest, tuser);
      end if;

      if (areset_n = '0') then
        tvalid <= '0';
        wait until areset_n = '1' and rising_edge(aclk);
      else
        if is_empty(message_queue) then
          -- Wait for messages to arrive on the queue, posted by the process above
          wait until (not is_empty(message_queue) or areset_n = '0') and rising_edge(aclk);
        end if;

        while not is_empty(message_queue) loop
          msg := pop(message_queue);
          msg_type := message_type(msg);

          if msg_type = wait_for_time_msg then
            handle_sync_message(net, msg_type, msg);
            -- Re-align with the clock when a wait for time message was handled, because this breaks edge alignment.
            wait until rising_edge(aclk);
          elsif msg_type = notify_request_msg then
            -- Ignore this message, but expect it
          elsif msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
            drive_invalid_output(tdata, tkeep, tstrb, tid, tdest, tuser);
            -- stall according to probability configuration
            probability_stall_axi_stream(aclk, master, rnd);

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
            wait until ((tvalid and tready) = '1' or areset_n = '0') and rising_edge(aclk);
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
    end loop;
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
        areset_n => areset_n,
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
