-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;
use work.axi_private_pkg.all;
use work.queue_pkg.all;
use work.memory_pkg.all;
use work.message_pkg.all;

entity axi_read_slave is
  generic (
    inbox : inbox_t;
    memory : memory_t);
  port (
    aclk : in std_logic;

    arvalid : in std_logic;
    arready : out std_logic;
    arid : in std_logic_vector;
    araddr : in std_logic_vector;
    arlen : in std_logic_vector;
    arsize : in std_logic_vector;
    arburst : in axi_burst_type_t;

    rvalid : out std_logic;
    rready : in std_logic;
    rid : out std_logic_vector;
    rdata : out std_logic_vector;
    rresp : out axi_resp_t;
    rlast : out std_logic;

    -- Set to non null_queue to disable error asserts
    -- Used for testing this entity only
    error_queue : in queue_t := null_queue
    );
end entity;

architecture a of axi_read_slave is
  shared variable self : axi_slave_t;
begin

  main : process
    variable burst : axi_burst_t;
    variable address : integer;
    variable idx : integer;
  begin
    self.init(inbox, rdata);

    -- Static Error checking
    assert arid'length = rid'length report "arid vs rid data width mismatch";
    assert (arlen'length = 4 or
            arlen'length = 8) report "arlen must be either 4 (AXI3) or 8 (AXI4)";

    -- Initialization
    rvalid <= '0';
    rid <= (rid'range => '0');
    rdata <= (rdata'range => '0');
    rresp <= (rresp'range => '0');
    rlast <= '0';

    loop
      -- Read AR channel
      arready <= '1';
      wait until (arvalid and arready) = '1' and rising_edge(aclk);
      arready <= '0';
      burst := decode_burst(arid, araddr, arlen, arsize, arburst);
      self.check_4kb_boundary(burst);

      if burst.burst_type = axi_burst_type_wrap then
        self.fail("Wrapping burst type not supported");
      end if;

      rid <= std_logic_vector(to_unsigned(burst.id, rid'length));
      rdata <= (rdata'range => '0');
      rresp <= axi_resp_ok;

      address := burst.address;

      for i in 0 to burst.length-1 loop
        for j in 0 to burst.size-1 loop
          idx := (address + j) mod self.data_size;
          rdata(8*idx+7 downto 8*idx) <= std_logic_vector(to_unsigned(read_byte(memory, address+j), 8));
        end loop;

        if burst.burst_type = axi_burst_type_incr then
          address := address + burst.size;
        end if;

        if i = burst.length - 1 then
          rlast <= '1';
        else
          rlast <= '0';
        end if;

        rvalid <= '1';
        wait until (rvalid and rready) = '1' and rising_edge(aclk);
        rvalid <= '0';
      end loop;

    end loop;
  end process;

  error_queue_set : process (error_queue)
  begin
    self.set_error_queue(error_queue);
  end process;
end architecture;
