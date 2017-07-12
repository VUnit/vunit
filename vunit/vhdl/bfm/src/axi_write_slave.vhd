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
context work.com_context;

entity axi_write_slave is
  generic (
    axi_slave : axi_slave_t;
    memory : memory_t);
  port (
    aclk : in std_logic;

    awvalid : in std_logic;
    awready : out std_logic := '0';
    awid : in std_logic_vector;
    awaddr : in std_logic_vector;
    awlen : in std_logic_vector;
    awsize : in std_logic_vector;
    awburst : in axi_burst_type_t;

    wvalid : in std_logic;
    wready : out std_logic := '0';
    wid : in std_logic_vector;
    wdata : in std_logic_vector;
    wstrb : in std_logic_vector;
    wlast : in std_logic;

    bvalid : out std_logic := '0';
    bready : in std_logic;
    bid : out std_logic_vector;
    bresp : out axi_resp_t
    );
end entity;

architecture a of axi_write_slave is
  shared variable self : axi_slave_private_t;
  signal initialized : boolean := false;
begin

  control_process : process
  begin
    self.init(axi_slave, wdata);
    initialized <= true;
    main_loop(self, event);
    wait;
  end process;

  axi_process : process
    variable resp_burst, burst : axi_burst_t;
    variable address : integer;
    variable idx : integer;
    variable beats : natural := 0;
  begin
    -- Initialization
    bid <= (bid'range => '0');
    bresp <= (bresp'range => '0');

    assert awid'length = bid'length report "arwid vs wid data width mismatch";
    assert (awlen'length = 4 or
            awlen'length = 8) report "awlen must be either 4 (AXI3) or 8 (AXI4)";

    wait on initialized until initialized;

    loop
      if bready = '1' then
        bvalid <= '0';
      end if;

      if (awvalid and awready) = '1' then
        self.push_burst(awid, awaddr, awlen, awsize, awburst);
      end if;

      if (wvalid and wready) = '1' then
        if (wlast = '1') /= (beats = 1) then
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

        beats := beats - 1;
        if beats = 0 then
          self.push_resp(burst);
        end if;
      end if;

      if not (self.burst_queue_empty or beats > 0) then
        burst := self.pop_burst;
        address := burst.address;
        beats := burst.length;
      end if;

      if not self.resp_queue_empty then
        resp_burst := self.pop_resp;
        bvalid <= '1';
        bid <= std_logic_vector(to_unsigned(resp_burst.id, bid'length));
        bresp <= axi_resp_okay;
      end if;

      if beats > 0 and not (beats = 1 and self.resp_queue_full) then
        wready <= '1';
      else
        wready <= '0';
      end if;

      if self.should_stall_address_channel or self.burst_queue_full then
        awready <= '0';
      else
        awready <= '1';
      end if;

      wait until rising_edge(aclk);
    end loop;
  end process;

  well_behaved_check : process
    variable size, len : natural;
    variable num_beats : integer := 0;
    variable num_beats_now : integer;
  begin
    wait on initialized until initialized;
    loop

      num_beats_now := num_beats;

      if awvalid = '1' then
        len       := to_integer(unsigned(awlen));
        num_beats_now := num_beats + len + 1;
      end if;

      -- Always keep track of num_beats such that the well behaved check can be enabled at any time
      if (awvalid and awready) = '1' then
        size      := 2**to_integer(unsigned(awsize));
        num_beats := num_beats_now;

        if self.should_check_well_behaved and size /= self.data_size and len /= 0 then
          self.fail("Burst not well behaved, axi size = " & to_string(size) & " but bus data width allows " & to_string(self.data_size));
        end if;
      end if;

      if self.should_check_well_behaved and num_beats_now > 0 and wvalid /= '1' then
        self.fail("Burst not well behaved, vwalid was not high during active burst");
      end if;

      if self.should_check_well_behaved and num_beats_now > 0 and bready /= '1' then
        self.fail("Burst not well behaved, bready was not high during active burst");
      end if;

      if (wvalid and wready) = '1' then
        num_beats := -1;
      end if;

      wait until rising_edge(aclk);
    end loop;
    wait;
  end process;

end architecture;
