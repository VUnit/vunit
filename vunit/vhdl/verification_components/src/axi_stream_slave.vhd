-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_slave_pkg.all;
use work.axi_stream_pkg.all;
use work.axi_stream_private_pkg.all;
use work.sync_pkg.all;
use work.string_ptr_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

entity axi_stream_slave is
  generic (
    slave : axi_stream_slave_t);
  port (
    aclk     : in std_logic;
    areset_n : in std_logic  := '1';
    tvalid   : in std_logic;
    tready   : out std_logic := '0';
    tdata    : in std_logic_vector(data_length(slave)-1 downto 0);
    tlast    : in std_logic                                         := '1';
    tkeep    : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tstrb    : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tid      : in std_logic_vector(id_length(slave)-1 downto 0)     := (others => '0');
    tdest    : in std_logic_vector(dest_length(slave)-1 downto 0)   := (others => '0');
    tuser    : in std_logic_vector(user_length(slave)-1 downto 0)   := (others => '0')
 );
end entity;

architecture a of axi_stream_slave is

  constant notify_request_msg      : msg_type_t := new_msg_type("notify request");
  constant message_queue           : queue_t    := new_queue;
  signal   notify_bus_process_done : std_logic  := '0';

begin

  main : process
    variable request_msg    : msg_t;
    variable notify_msg     : msg_t;
    variable msg_type       : msg_type_t;
  begin
    receive(net, slave.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = stream_pop_msg or msg_type = pop_axi_stream_msg then
      push(message_queue, request_msg);
    elsif msg_type = check_axi_stream_msg then
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

    procedure check_field(got, exp : std_logic_vector; msg : string) is
    begin
      if got'length /= 0 and exp'length /= 0 then
        check_equal(got, exp, msg);
      end if;
    end procedure;

    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
    variable report_msg : string_ptr_t;
    variable axi_stream_transaction : axi_stream_transaction_t(
      tdata(tdata'range),
      tkeep(tkeep'range),
      tstrb(tstrb'range),
      tid(tid'range),
      tdest(tdest'range),
      tuser(tuser'range)
    );
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name);
    loop
      if is_empty(message_queue) then
        -- Wait for messages to arrive on the queue, posted by the process above
        wait until rising_edge(aclk) and (not is_empty(message_queue));
      end if;

      while not is_empty(message_queue) loop
        msg := pop(message_queue);
        msg_type := message_type(msg);

        if msg_type = wait_for_time_msg then
          handle_sync_message(net, msg_type, msg);
          wait until rising_edge(aclk);
        elsif msg_type = notify_request_msg then
          -- Ignore this message, but expect it
        elsif msg_type = stream_pop_msg or msg_type = pop_axi_stream_msg or msg_type = check_axi_stream_msg then

          -- stall according to probability configuration
          probability_stall_axi_stream(aclk, slave, rnd);

          tready <= '1';
          wait until (tvalid and tready) = '1' and rising_edge(aclk);
          tready <= '0';

          if msg_type = stream_pop_msg or msg_type = pop_axi_stream_msg then
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
          elsif msg_type = check_axi_stream_msg then
            report_msg := new_string_ptr(pop_string(msg));
            check_field(tdata, pop_std_ulogic_vector(msg), "TDATA mismatch, " & to_string(report_msg));
            check_field(tkeep, pop_std_ulogic_vector(msg), "TKEEP mismatch, " & to_string(report_msg));
            check_field(tstrb, pop_std_ulogic_vector(msg), "TSTRB mismatch, " & to_string(report_msg));
            check_equal(tlast, pop_std_ulogic(msg), "TLAST mismatch, " & to_string(report_msg));
            check_field(tid, pop_std_ulogic_vector(msg), "TID mismatch, " & to_string(report_msg));
            check_field(tdest, pop_std_ulogic_vector(msg), "TDEST mismatch, " & to_string(report_msg));
            check_field(tuser, pop_std_ulogic_vector(msg), "TUSER mismatch, " & to_string(report_msg));
          end if;

        else
          unexpected_msg_type(msg_type);
        end if;

        delete(msg);
      end loop;

      notify_bus_process_done <= '1';
      wait until notify_bus_process_done = '1';
      notify_bus_process_done <= '0';
    end loop;
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
