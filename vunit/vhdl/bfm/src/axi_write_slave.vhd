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

entity axi_write_slave is
  generic (
    memory : memory_t);
  port (
    aclk : in std_logic;

    awvalid : in std_logic;
    awready : out std_logic;
    awid : in std_logic_vector;
    awaddr : in std_logic_vector;
    awlen : in std_logic_vector;
    awsize : in std_logic_vector;
    awburst : in axi_burst_t;

    wvalid : in std_logic;
    wready : out std_logic;
    wid : in std_logic_vector;
    wdata : in std_logic_vector;
    wstrb : in std_logic_vector;
    wlast : in std_logic;

    bvalid : out std_logic;
    bready : in std_logic;
    bid : out std_logic_vector;
    bresp : out axi_resp_t;

    -- Set to non null_queue to disable error asserts
    -- Used for testing this entity only
    error_queue : in queue_t := null_queue
    );
end entity;

architecture a of axi_write_slave is
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
    variable start_address, address : integer;
    variable burst_length : integer;
    variable burst_size : integer;
    variable burst_type : axi_burst_t;

  begin
    -- Static Error checking
    assert awid'length = bid'length report "arwid vs wid data width mismatch";
    assert (awlen'length = 4 or
            awlen'length = 8) report "awlen must be either 4 (AXI3) or 8 (AXI4)";

    -- Initialization
    wready <= '0';
    bvalid <= '0';
    bid <= (bid'range => '0');
    bresp <= (bresp'range => '0');

    loop
      awready <= '1';
      wait until (awvalid and awready) = '1' and rising_edge(aclk);
      awready <= '0';
      start_address := to_integer(unsigned(awaddr));
      address := start_address;
      burst_length := to_integer(unsigned(awlen)) + 1;
      burst_size := 2**to_integer(unsigned(awsize));
      burst_type := awburst;

      if burst_type = axi_burst_wrap then
        fail("Wrapping burst type not supported");
      end if;

      bid <= awid;
      bresp <= axi_resp_ok;

      for i in 0 to burst_length-1 loop
        wready <= '1';
        wait until (wvalid and wready) = '1' and rising_edge(aclk);
        wready <= '0';

        for j in 0 to burst_size-1 loop
          if wstrb(j) = '1' then
            write_byte(memory, address+j, to_integer(unsigned(wdata(8*j+7 downto 8*j))));
          end if;
        end loop;

        if burst_type = axi_burst_incr then
          address := address + burst_size;
        end if;

        if (wlast = '1') /= (i = burst_length-1) then
          fail("Expected wlast='1' on last beat of burst with length " & to_string(burst_length) &
               " starting at address " & to_string(start_address));
        end if;
      end loop;

      bvalid <= '1';
      wait until (bvalid and bready) = '1' and rising_edge(aclk);
      bvalid <= '0';
    end loop;
  end process;
end architecture;
