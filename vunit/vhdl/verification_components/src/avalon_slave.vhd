-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
--
-- Avalon memory mapped slave wrapper for Vunit memory VC

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.avalon_pkg.avalon_slave_t;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.memory_pkg.all;

entity avalon_slave is
  generic (
    avalon_slave : avalon_slave_t
  );
  port (
    clk           : in std_logic;
    address       : in  std_logic_vector;
    byteenable    : in  std_logic_vector;
    burstcount    : in  std_logic_vector;
    waitrequest   : out std_logic;
    write         : in  std_logic;
    writedata     : in  std_logic_vector;
    read          : in  std_logic;
    readdata      : out std_logic_vector;
    readdatavalid : out std_logic
  );
end entity;

architecture a of avalon_slave is

  constant slave_read_msg   : msg_type_t := new_msg_type("avmm slave read");

begin

  write_handler : process
    variable pending_writes : positive := 1;
    variable addr : natural;
    variable word_i : std_logic_vector(writedata'length-1 downto 0);
    variable byteenable_i : std_logic_vector(byteenable'length-1 downto 0);
  begin
    loop
      wait until write = '1' and waitrequest = '0' and rising_edge(clk);
      word_i := writedata;
      byteenable_i := byteenable;
      -- Burst write in progress
      if pending_writes > 1 then
        addr := addr + byteenable'length;
        pending_writes := pending_writes -1;
      -- Burst start or single burst
      else
        addr := to_integer(unsigned(address));
        pending_writes := to_integer(unsigned(burstcount));
      end if;
      for idx in 0 to word_i'length/8-1 loop
        if byteenable_i(idx) then
          write_byte(avalon_slave.p_memory, addr + idx, to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
        end if;
      end loop;
    end loop;
  end process;

  read_request : process
    variable rd_request_msg : msg_t;
  begin
    wait until read = '1' and waitrequest = '0' and rising_edge(clk);
    rd_request_msg := new_msg(slave_read_msg, avalon_slave.p_actor);
    -- For read, only address is passed to ack proc
    push_integer(rd_request_msg, to_integer(unsigned(burstcount)));
    push_integer(rd_request_msg, to_integer(unsigned(address)));
    send(net, avalon_slave.p_ack_actor, rd_request_msg);
  end process;

  read_handler : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable baseaddr : natural;
    variable burst : positive;
    variable rnd : RandomPType;
  begin
    readdatavalid <= '0';
    receive(net, avalon_slave.p_ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = slave_read_msg then
      burst := pop_integer(request_msg);
      baseaddr := pop_integer(request_msg);
      for i in 0 to burst-1 loop
        while rnd.Uniform(0.0, 1.0) > avalon_slave.readdatavalid_high_probability loop
          wait until rising_edge(clk);
        end loop;
        readdata <= read_word(avalon_slave.p_memory, baseaddr + byteenable'length*i, byteenable'length);
        readdatavalid <= '1';
        wait until rising_edge(clk);
        readdatavalid <= '0';
      end loop;

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  waitrequest_stim: process
    variable rnd : RandomPType;
  begin
    if rnd.Uniform(0.0, 1.0) < avalon_slave.waitrequest_high_probability then
      waitrequest <= '1';
    else
      waitrequest <= '0';
    end if;
    wait until rising_edge(clk);
  end process;
end architecture;
