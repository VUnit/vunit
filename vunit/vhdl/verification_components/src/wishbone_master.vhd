-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Wishbome Master BFM for pipelined block transfers

library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.bus_master_pkg.all;
context work.com_context;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.check_pkg.all;
use work.log_levels_pkg.all;
use work.sync_pkg.all;
use work.wishbone_pkg.all;
use work.vc_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity wishbone_master is
  generic (
    wishbone_master : wishbone_master_t
    );
  port (
    clk   : in std_logic;
    adr   : out std_logic_vector;
    dat_i : in  std_logic_vector;
    dat_o : out std_logic_vector;
    sel   : out std_logic_vector;
    cyc   : out std_logic;
    stb   : out std_logic;
    we    : out std_logic;
    stall : in std_logic;
    ack   : in  std_logic
    );
end entity;

architecture a of wishbone_master is
  constant acknowledge_queue : queue_t := new_queue;
  constant wb_master_ack_actor : actor_t := new_actor;
  signal start_cycle : std_logic := '0';
  signal end_cycle : std_logic := '0';
  signal cycle : boolean;
begin

  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable cycle_type : msg_type_t;
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name);

    request_msg := null_msg;
    cycle_type := bus_read_msg;
    stb <= '0';

    loop
      receive(net, get_actor(wishbone_master), request_msg);
      msg_type := message_type(request_msg);

      if msg_type = bus_read_msg or msg_type = bus_write_msg then
        if msg_type /= cycle_type and cycle then
          wait until not cycle; -- TODO: is this necessary? the wb spec v4 does not explicitly forbid mixed cycles
          wait until rising_edge(clk);
        end if;

        start_cycle <= not start_cycle;
        cycle_type := msg_type;

        while rnd.Uniform(0.0, 1.0) > wishbone_master.p_strobe_high_probability loop
          wait until rising_edge(clk);
        end loop;
        adr <= pop_std_ulogic_vector(request_msg);
        stb <= '1';
        if msg_type = bus_write_msg then
          we <= '1';
          dat_o <= pop_std_ulogic_vector(request_msg);
          sel <= pop_std_ulogic_vector(request_msg);
        else
          we <= '0';
        end if;
        push(acknowledge_queue, request_msg);
        wait until rising_edge(clk) and stall = '0';
        stb <= '0';

      elsif msg_type = wait_until_idle_msg or msg_type = wait_for_time_msg then
        if cycle then
          wait until not cycle;
        end if;
        handle_sync_message(net, msg_type, request_msg);

      else
        unexpected_msg_type(msg_type, get_std_cfg(wishbone_master));
      end if;

    end loop;
  end process;

  p_cycle : process
    variable pending : natural := 0;
  begin
    cyc <= '0';
    cycle <= false;

    loop
      wait until start_cycle'event or end_cycle'event;

      if start_cycle'event then
        pending := pending+1;
      end if;
      if end_cycle'event then
        pending := pending-1;
      end if;
      check_true(pending >= 0, "Pending transactions became negative - internal error", failure);

      if pending > 0 then
        cyc <= '1';
        cycle <= true;
      else
        cyc <= '0';
        cycle <= false;
      end if;
    end loop;
  end process;

  acknowledge : process
    variable request_msg, reply_msg : msg_t;
  begin
    wait until ack = '1' and rising_edge(clk);
    request_msg := pop(acknowledge_queue);
    -- Reply only on read
    if we = '0' then
      reply_msg := new_msg(sender => wb_master_ack_actor);
      push_std_ulogic_vector(reply_msg, dat_i);
      reply(net, request_msg, reply_msg);
    end if;
    delete(request_msg);
    -- Response main sequencer that ack is received
    end_cycle <= not end_cycle;
  end process;
end architecture;
