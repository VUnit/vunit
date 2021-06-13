-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_master_pkg.all;
use work.axi_stream_pkg.all;
use work.axi_stream_private_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;
use work.vc_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

entity axi_stream_master is
  generic (
    master : axi_stream_master_t
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
  constant message_queue, transaction_token_queue : queue_t    := new_queue;
  signal notification : boolean := false;
  procedure drive_invalid_output(signal l_tdata : out std_logic_vector(data_length(master)-1 downto 0);
                                 signal l_tkeep : out std_logic_vector(data_length(master)/8-1 downto 0);
                                 signal l_tstrb : out std_logic_vector(data_length(master)/8-1 downto 0);
                                 signal l_tid   : out std_logic_vector(id_length(master)-1 downto 0);
                                 signal l_tdest : out std_logic_vector(dest_length(master)-1 downto 0);
                                 signal l_tuser : out std_logic_vector(user_length(master)-1 downto 0))
  is
  begin
    l_tdata <= (others => master.p_drive_invalid_val);
    l_tkeep <= (others => master.p_drive_invalid_val);
    l_tstrb <= (others => master.p_drive_invalid_val);
    l_tid   <= (others => master.p_drive_invalid_val);
    l_tdest <= (others => master.p_drive_invalid_val);
    l_tuser <= (others => master.p_drive_invalid_val_user);
  end procedure;

begin

  main : process
    variable request_msg : msg_t;
    variable msg_type    : msg_type_t;
    variable timestamp : time;

    procedure wait_on_pending_transactions is
  begin
      if not is_empty(transaction_token_queue) then
        wait on notification until is_empty(transaction_token_queue);
      end if;
    end;
  begin
    receive(net, get_actor(master.p_std_cfg), request_msg);
    msg_type := message_type(request_msg);

    if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
      push(message_queue, request_msg);
      push(transaction_token_queue, true);
    elsif msg_type = wait_for_time_msg then
      wait_on_pending_transactions;
      handle_wait_for_time(net, msg_type, request_msg);
    elsif msg_type = wait_until_idle_msg then
      wait_on_pending_transactions;
      loop
        timestamp := now;
        if master.p_monitor /= null_axi_stream_monitor then
          wait_until_idle(net, as_sync(master.p_monitor));
        end if;
        if master.p_protocol_checker /= null_axi_stream_protocol_checker then
          wait_until_idle(net, as_sync(master.p_protocol_checker));
        end if;
        exit when now = timestamp;
      end loop;
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type, master.p_std_cfg);
    end if;
  end process;

  bus_process : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable not_used : boolean;
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name);
    loop
      if master.p_drive_invalid then
        drive_invalid_output(tdata, tkeep, tstrb, tid, tdest, tuser);
      end if;

      -- Wait for messages to arrive on the queue, posted by the process above
    wait until (rising_edge(aclk) and not is_empty(message_queue)) or areset_n = '0';

      if (areset_n = '0') then
        tvalid <= '0';
      else
        while not is_empty(message_queue) loop
          msg := pop(message_queue);
          msg_type := message_type(msg);

        if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
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
          wait until (rising_edge(aclk) and (tvalid and tready) = '1') or areset_n = '0';
            tvalid <= '0';
            tlast <= '0';

          not_used := pop(transaction_token_queue);
          notification <= not notification;
          wait on notification;
        else
          unexpected_msg_type(msg_type, master.p_std_cfg);
          end if;

          delete(msg);
        end loop;
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

    repeater : if master.p_use_default_monitor generate
      process
        constant subscriber : actor_t := new_actor;
        variable msg        : msg_t;
      begin
        subscribe(subscriber, get_actor(master.p_monitor.p_std_cfg));
        loop
          receive(net, subscriber, msg);
          publish(net, get_actor(master.p_std_cfg), msg);
        end loop;
      end process;
    end generate;

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
