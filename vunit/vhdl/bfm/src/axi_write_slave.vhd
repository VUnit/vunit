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
    awburst : in axi_burst_type_t;

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
  shared variable self : axi_slave_t;
begin

  main : process

    variable burst : axi_burst_t;
    variable address : integer;
    variable idx : integer;
  begin
    self.init(wdata);

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
      burst := decode_burst(awid, awaddr, awlen, awsize, awburst);
      self.check_4kb_boundary(burst);

      if burst.burst_type = axi_burst_type_wrap then
        self.fail("Wrapping burst type not supported");
      end if;

      bid <= std_logic_vector(to_unsigned(burst.id, bid'length));
      bresp <= axi_resp_ok;

      address := burst.address;
      for i in 0 to burst.length-1 loop
        wready <= '1';
        wait until (wvalid and wready) = '1' and rising_edge(aclk);
        wready <= '0';

        if (wlast = '1') /= (i = burst.length-1) then
          self.fail("Expected wlast='1' on last beat of burst with length " & to_string(burst.length) &
                    " starting at address " & to_string(burst.address));
        end if;

        for j in 0 to burst.size-1 loop
          idx := (address + j) mod self.data_size; -- Align data bus
          if wstrb(idx) = '1' then
            write_byte(memory, address+j, to_integer(unsigned(wdata(8*idx+7 downto 8*idx))));
          end if;
        end loop;

        if burst.burst_type = axi_burst_type_incr then
          address := address + burst.size;
        end if;
      end loop;

      bvalid <= '1';
      wait until (bvalid and bready) = '1' and rising_edge(aclk);
      bvalid <= '0';
    end loop;
  end process;

  error_queue_set : process (error_queue)
  begin
    self.set_error_queue(error_queue);
  end process;
end architecture;
