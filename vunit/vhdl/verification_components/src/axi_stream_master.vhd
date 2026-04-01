-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_stream_pkg.all;
use work.axi_stream_private_pkg.all;
use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_types_pkg.all;
use work.id_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;
use work.stream_master_pkg.stream_push_msg;
use work.sync_pkg.all;
use work.event_common_pkg.is_active;
use work.event_common_pkg.notify;
use work.event_pkg.all;
use work.logger_pkg.all;
use work.axi_pkg.all;

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
    tkeep        : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '1');
    tstrb        : out std_logic_vector(data_length(master)/8-1 downto 0) := (others => '1');
    tid          : out std_logic_vector(id_length(master)-1 downto 0)     := (others => '0');
    tdest        : out std_logic_vector(dest_length(master)-1 downto 0)   := (others => '0');
    tuser        : out std_logic_vector(user_length(master)-1 downto 0)   := (others => '0')
  );
end entity;

architecture a of axi_stream_master is

  constant notify_request_msg      : msg_type_t := new_msg_type("notify request");
  constant message_queue           : queue_t    := new_queue;
  constant bus_process_done_base_id : id_t       := get_id("vunit_lib:axi_stream_master:bus_process_done");
  constant bus_process_done_id      : id_t       := get_id(
      to_string(num_children(bus_process_done_base_id)),
      parent => bus_process_done_base_id
    );
  signal bus_process_done           : event_t    := new_event(bus_process_done_id);
begin

  main : process
    variable request_msg : msg_t;
    variable notify_msg  : msg_t;
    variable msg_type    : msg_type_t;
  begin
    receive(net, master.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = stream_push_msg or
      msg_type = push_axi_stream_msg or
      msg_type = wait_for_time_msg or
      msg_type = set_inactive_axi_stream_policy_msg or
      msg_type = set_stall_config_msg then

      push(message_queue, request_msg);

    elsif msg_type = wait_until_idle_msg then
      notify_msg := new_msg(notify_request_msg);
      push(message_queue, notify_msg);
      wait until is_active(bus_process_done) and is_empty(message_queue);
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  bus_process : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable inactive_axi_stream_policy : inactive_axi_stream_policy_t := get_inactive_axi_stream_policy(master);
    variable inactive_bus_policy : inactive_bus_policy_t;
    variable axi_stream_signal : axi_stream_signal_t;

    procedure probability_stall_axi_stream(
      signal aclk : in std_logic;
      axi_stream  : in axi_stream_master_t;
      rnd         : inout RandomPType) is
    begin
      probability_stall_axi_stream(aclk, get_stall_config(axi_stream), rnd);
    end procedure;

    procedure drive_inactive(
      signal l_tdata : out std_logic_vector(data_length(master)-1 downto 0);
      signal l_tlast : out std_logic;
      signal l_tkeep : out std_logic_vector(data_length(master)/8-1 downto 0);
      signal l_tstrb : out std_logic_vector(data_length(master)/8-1 downto 0);
      signal l_tid   : out std_logic_vector(id_length(master)-1 downto 0);
      signal l_tdest : out std_logic_vector(dest_length(master)-1 downto 0);
      signal l_tuser : out std_logic_vector(user_length(master)-1 downto 0)
    ) is

      procedure drive_policy(signal s : out std_logic_vector; policy : inactive_bus_policy_t) is
      begin
        case policy is
          when 'X' =>
            s <= (s'range => 'X');
          when '0' =>
            s <= (s'range => '0');
          when '1' =>
            s <= (s'range => '1');
          when hold =>
            null;
        end case;
      end;

      procedure drive_policy(signal s : out std_logic; policy : inactive_bus_policy_t) is
      begin
        case policy is
          when 'X' =>
            s <= 'X';
          when '0' =>
            s <= '0';
          when '1' =>
            s <= '1';
          when hold =>
            null;
        end case;
      end;

    begin
      drive_policy(l_tdata, inactive_axi_stream_policy(work.axi_stream_pkg.tdata));
      drive_policy(l_tlast, inactive_axi_stream_policy(work.axi_stream_pkg.tlast));
      drive_policy(l_tkeep, inactive_axi_stream_policy(work.axi_stream_pkg.tkeep));
      drive_policy(l_tstrb, inactive_axi_stream_policy(work.axi_stream_pkg.tstrb));
      drive_policy(l_tid, inactive_axi_stream_policy(work.axi_stream_pkg.tid));
      drive_policy(l_tdest, inactive_axi_stream_policy(work.axi_stream_pkg.tdest));
      drive_policy(l_tuser, inactive_axi_stream_policy(work.axi_stream_pkg.tuser));
    end procedure;

  begin
    rnd.InitSeed(rnd'instance_name);
    loop
      drive_inactive(tdata, tlast, tkeep, tstrb, tid, tdest, tuser);
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
            drive_inactive(tdata, tlast, tkeep, tstrb, tid, tdest, tuser);

          elsif msg_type = set_inactive_axi_stream_policy_msg then
            inactive_bus_policy := inactive_bus_policy_t'val(pop_integer(msg));
            axi_stream_signal := axi_stream_signal_t'val(pop_integer(msg));
            set_inactive_axi_stream_policy(master, inactive_bus_policy, axi_stream_signal);
            inactive_axi_stream_policy := get_inactive_axi_stream_policy(master);

          elsif msg_type = set_stall_config_msg then
            deallocate(to_integer_vector_ptr(get(master.p_config, p_stall_config_idx)));
            set(master.p_config, p_stall_config_idx, to_integer(pop_integer_vector_ptr_ref(msg)));

          else
            unexpected_msg_type(msg_type);
          end if;

          delete(msg);
        end loop;

        notify(bus_process_done);
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

  deprecation_message : process is
  begin
    warning_if(
      master.p_logger,
      drive_invalid,
      "The drive_invalid generics have been deprecated. Bus inactivity is now controlled " &
      "by the inactive_bus_policy parameter to the new_axi_stream_master function."
    );

    wait;
  end process;

end architecture;
