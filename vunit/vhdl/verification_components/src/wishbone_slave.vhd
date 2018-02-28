-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Slawomir Siluk slaweksiluk@gazeta.pl 2018
-- Wishbone slave wrapper for Vunit memory VC
-- TODO:
-- - wb sel
-- - stall (random)
-- - random ack delay
-- - err and rty responses
-- - variable memory size (currenlty 1024Bytes)
-- - variable address range
-- - consider passing memory object to slave instead of
--   create it locally

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

use work.memory_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity wishbone_slave is
  generic (
    --bus_handle : bus_master_t
    rand_ack    : boolean := true
  );
  port (
    clk   : in std_logic;
    adr   : in std_logic_vector;
    dat_i : in  std_logic_vector;
    dat_o : out std_logic_vector;
    sel   : in std_logic_vector;
    cyc   : in std_logic;
    stb   : in std_logic;
    we    : in std_logic;
    ack   : out  std_logic
    );
end entity;

architecture a of wishbone_slave is

  constant ack_actor        : actor_t := new_actor("slave ack actor");
  constant slave_logger     : logger_t := get_logger("slave");
  constant slave_write_msg  : msg_type_t := new_msg_type("wb slave write");
  constant slave_read_msg   : msg_type_t := new_msg_type("wb slave read");
  constant max_ack_dly      : positive := 3;
begin

  show(slave_logger, display_handler, verbose);

  request : process
    variable wr_request_msg : msg_t;
    variable rd_request_msg : msg_t;
  begin
    wait until (cyc and stb) = '1' and rising_edge(clk);
    if we = '1' then
      wr_request_msg := new_msg(slave_write_msg);
      -- For write address and data is passed to ack proc
      push_integer(wr_request_msg, to_integer(unsigned(adr)));
      push_std_ulogic_vector(wr_request_msg, dat_i);
      send(net, ack_actor, wr_request_msg);
    elsif we = '0' then
      rd_request_msg := new_msg(slave_read_msg);
      -- For read, only address is passed to ack proc
      push_integer(rd_request_msg, to_integer(unsigned(adr)));
      send(net, ack_actor, rd_request_msg);
    end if;
  end process;

  acknowledge : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable data : std_logic_vector(dat_i'range);
    variable addr : natural;
    variable memory : memory_t := new_memory;
    variable buf : buffer_t := allocate(memory, 1024);
    variable rnd : RandomPType;
  begin
    ack <= '0';
    receive(net, ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = slave_write_msg then
      addr := pop_integer(request_msg);
      data := pop_std_ulogic_vector(request_msg);
      write_word(memory, addr, data);
      for i in 1 to rnd.RandInt(1, max_ack_dly) loop
        wait until rising_edge(clk);
      end loop;
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';

    elsif msg_type = slave_read_msg then
      data := (others => '0');
      addr := pop_integer(request_msg);
      data := read_word(memory, addr, 1);
      dat_o <= data;
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;
end architecture;
