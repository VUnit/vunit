-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon Memory Mapped Master BFM
-- TODO:
-- - handle byteenable in bursts

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.bus_master_pkg.all;
use work.check_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

entity avalon_master is
  generic (
    bus_handle          : bus_master_t;
    use_readdatavalid   : boolean := true;
    fixed_read_latency  : natural := 1;  -- (bus cycles).  This parameter is ignored when use_readdatavalid is true
    write_high_probability : real range 0.0 to 1.0 := 1.0;
    read_high_probability : real range 0.0 to 1.0 := 1.0
  );
  port (
    clk           : in  std_logic;
    address       : out std_logic_vector;
    byteenable    : out std_logic_vector;
    burstcount    : out std_logic_vector;
    waitrequest   : in  std_logic;
    write         : out std_logic;
    writedata     : out std_logic_vector;
    read          : out std_logic;
    readdata      : in  std_logic_vector;
    readdatavalid : in  std_logic
  );
end entity;

architecture a of avalon_master is
  constant av_master_read_actor : actor_t := new_actor;
  constant avmm_burst_rd_actor : actor_t := new_actor;
  constant acknowledge_queue : queue_t := new_queue;
  constant burst_acknowledge_queue : queue_t := new_queue;
  constant burstlen_queue : queue_t := new_queue;
begin

  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable msgs : natural;
    variable burst : positive;
  begin
    rnd.InitSeed(rnd'instance_name);
    write <= '0';
    read  <= '0';
    burstcount <= std_logic_vector(to_unsigned(1, burstcount'length));
    wait until rising_edge(clk);
    loop
      request_msg := null_msg;
      msgs := num_of_messages(bus_handle.p_actor);
      if (msgs > 0) then
        receive(net, bus_handle.p_actor, request_msg);
        msg_type := message_type(request_msg);
        if msg_type = bus_read_msg then
          while rnd.Uniform(0.0, 1.0) > read_high_probability loop
            wait until rising_edge(clk);
          end loop;
          address <= pop_std_ulogic_vector(request_msg);
          byteenable(byteenable'range) <= (others => '1');
          read <= '1';
          push(acknowledge_queue, request_msg);
          wait until rising_edge(clk) and waitrequest = '0';
          read <= '0';

        elsif msg_type = bus_burst_read_msg then
          while rnd.Uniform(0.0, 1.0) > read_high_probability loop
            wait until rising_edge(clk);
          end loop;
          address <= pop_std_ulogic_vector(request_msg);
          burstcount <= std_logic_vector(to_unsigned(1, burstcount'length));
          burst := pop_integer(request_msg);
          burstcount <= std_logic_vector(to_unsigned(burst, burstcount'length));
          byteenable(byteenable'range) <= (others => '1');
          read <= '1';
          push(burst_acknowledge_queue, request_msg);
          wait until rising_edge(clk) and waitrequest = '0';
          read <= '0';
          push(burstlen_queue, burst);

        elsif msg_type = bus_write_msg then
          while rnd.Uniform(0.0, 1.0) > write_high_probability loop
            wait until rising_edge(clk);
          end loop;
          address <= pop_std_ulogic_vector(request_msg);
          burstcount <= std_logic_vector(to_unsigned(1, burstcount'length));
          writedata <= pop_std_ulogic_vector(request_msg);
          byteenable <= pop_std_ulogic_vector(request_msg);
          write <= '1';
          wait until rising_edge(clk) and waitrequest = '0';
          write <= '0';

        elsif msg_type = bus_burst_write_msg then
          address <= pop_std_ulogic_vector(request_msg);
          burst := pop_integer(request_msg);
          burstcount <= std_logic_vector(to_unsigned(burst, burstcount'length));
          for i in 0 to burst-1 loop
            while rnd.Uniform(0.0, 1.0) > write_high_probability loop
              wait until rising_edge(clk);
            end loop;
            writedata <= pop_std_ulogic_vector(request_msg);
            -- TODO handle byteenable
            byteenable(byteenable'range) <= (others => '1');
            write <= '1';
            wait until rising_edge(clk) and waitrequest = '0';
            write <= '0';
            address(address'range) <= (others => 'U');
            burstcount(burstcount'range) <= (others => 'U');
          end loop;

        elsif msg_type = wait_until_idle_msg then
          wait until is_empty(burst_acknowledge_queue) and rising_edge(clk);
          handle_wait_until_idle(net, msg_type, request_msg);

        else
          unexpected_msg_type(msg_type);
        end if;
      else
        wait until rising_edge(clk);
      end if;
    end loop;
  end process;

  read_capture : process
    variable request_msg, reply_msg : msg_t;
  begin
    if use_readdatavalid then
        wait until readdatavalid = '1' and not is_empty(acknowledge_queue) and rising_edge(clk);
    else
        -- Non-pipelined case: waits for slave to de-assert waitrequest and sample data after fixed_read_latency cycles.
        wait until rising_edge(clk) and waitrequest = '0' and read = '1';
        if fixed_read_latency > 0 then
            for i in 0 to fixed_read_latency - 1 loop
                wait until rising_edge(clk);
            end loop;
        end if;
    end if;
    request_msg := pop(acknowledge_queue);
    reply_msg := new_msg(sender => av_master_read_actor);
    push_std_ulogic_vector(reply_msg, readdata);
    reply(net, request_msg, reply_msg);
    delete(request_msg);
  end process;

  burst_read_capture : process
    variable request_msg, reply_msg : msg_t;
    variable burst : positive;
  begin
    wait until readdatavalid = '1' and not is_empty(burst_acknowledge_queue) and rising_edge(clk);
    burst := pop(burstlen_queue);
    reply_msg := new_msg(sender => avmm_burst_rd_actor);
    push_integer(reply_msg, burst);
    push_std_ulogic_vector(reply_msg, readdata);
    for i in 1 to burst-1 loop
      wait until readdatavalid = '1' and rising_edge(clk) for 1 us;
      check_true(readdatavalid = '1', "avalon master burst readdatavalid timeout");
      push_std_ulogic_vector(reply_msg, readdata);
    end loop;
    request_msg := pop(burst_acknowledge_queue);
    reply(net, request_msg, reply_msg);
    delete(request_msg);
  end process;

end architecture;
