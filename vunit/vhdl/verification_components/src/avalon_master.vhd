-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Avalon Memory Mapped Master BFM
-- - support burstcount > 1

library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.bus_master_pkg.all;
context work.com_context;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.check_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

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
  constant acknowledge_queue : queue_t := new_queue;
begin

  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable rnd : RandomPType;
    variable msgs : natural;
  begin
    rnd.InitSeed(rnd'instance_name);
    write <= '0';
    read  <= '0';
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
          wait until rising_edge(clk) and waitrequest = '0';
          read <= '0';
          push(acknowledge_queue, request_msg);

        elsif msg_type = bus_write_msg then
          while rnd.Uniform(0.0, 1.0) > write_high_probability loop
            wait until rising_edge(clk);
          end loop;
          address <= pop_std_ulogic_vector(request_msg);
          writedata <= pop_std_ulogic_vector(request_msg);
          byteenable <= pop_std_ulogic_vector(request_msg);
          write <= '1';
          wait until rising_edge(clk) and waitrequest = '0';
          write <= '0';

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
        wait until readdatavalid = '1' and rising_edge(clk);
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

  burstcount <= "1";
end architecture;
