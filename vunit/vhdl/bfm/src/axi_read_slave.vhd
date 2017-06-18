-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;
use work.queue_pkg.all;
use work.memory_pkg.all;

entity axi_read_slave is
  generic (
    memory : memory_t);
  port (
    aclk : in std_logic;

    arvalid : in std_logic;
    arready : out std_logic;
    arid : in std_logic_vector;
    araddr : in std_logic_vector;
    arlen : in std_logic_vector;
    arsize : in std_logic_vector;
    arburst : in axi_burst_t;

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
  procedure fail(msg : string) is
  begin
    if error_queue /= null_queue then
      push_string(error_queue, msg);
    else
      report msg severity failure;
    end if;
  end procedure;
begin

  main : process
    variable address : integer;
    variable burst_length : integer;
    variable burst_size : integer;
    variable burst_type : axi_burst_t;
  begin
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
      address := to_integer(unsigned(araddr));
      burst_length := to_integer(unsigned(arlen)) + 1;
      burst_size := 2**to_integer(unsigned(arsize));
      burst_type := arburst;
      rid <= arid;

      if burst_type = axi_burst_wrap then
        fail("Wrapping burst type not supported");
      end if;

      rdata <= (rdata'range => '0');
      rresp <= axi_resp_ok;

      for i in 0 to burst_length-1 loop
        for j in 0 to burst_size-1 loop
          rdata(8*j+7 downto 8*j) <= std_logic_vector(to_unsigned(read_byte(memory, address+j), 8));
        end loop;

        if burst_type = axi_burst_incr then
          address := address + burst_size;
        end if;

        rvalid <= '1';

        if i = burst_length - 1 then
          rlast <= '1';
        else
          rlast <= '0';
        end if;

        wait until (rvalid and rready) = '1' and rising_edge(aclk);
        rvalid <= '0';
      end loop;

    end loop;
  end process;

end architecture;
