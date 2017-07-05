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

entity axi_write_slave is
  generic (
    axi_slave : axi_slave_t;
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
    bresp : out axi_resp_t
    );
end entity;

architecture a of axi_write_slave is
  shared variable self : axi_slave_private_t;
  signal local_event : event_t := no_event;
begin

  main : process
  begin
    -- Static Error checking
    assert awid'length = bid'length report "arwid vs wid data width mismatch";
    self.init(axi_slave, wdata);
    main_loop(self, event);
    wait;
  end process;

  address_channel(self,
                  local_event,
                  aclk,
                  awvalid,
                  awready,
                  awid,
                  awaddr,
                  awlen,
                  awsize,
                  awburst);

  write_data : process
    variable burst : axi_burst_t;
    variable address : integer;
    variable idx : integer;
    variable msg : msg_t;
  begin
    -- Initialization
    wready <= '0';
    bvalid <= '0';
    bid <= (bid'range => '0');
    bresp <= (bresp'range => '0');

    wait until self.is_initialized and rising_edge(aclk);

    loop
      recv(local_event, self.get_addr_inbox, msg);
      burst := pop_axi_burst(msg.data);
      recycle(msg);

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
      bid <= std_logic_vector(to_unsigned(burst.id, bid'length));
      bresp <= axi_resp_ok;
      wait until (bvalid and bready) = '1' and rising_edge(aclk);
      bvalid <= '0';
    end loop;
  end process;

  well_behaved_check : process
    variable size, len : natural;
    variable num_beats : integer := 0;
  begin
    wait until self.is_initialized and rising_edge(aclk);
    loop

      -- Always keep track of num_beats such that the well behaved check can be enabled at any time
      if (awvalid and awready) = '1' then
        size      := 2**to_integer(unsigned(awsize));
        len       := to_integer(unsigned(awlen));
        num_beats := num_beats + len + 1;

        if self.should_check_well_behaved and size /= self.data_size and len /= 0 then
          self.fail("Burst not well behaved, axi size = " & to_string(size) & " but bus data width allows " & to_string(self.data_size));
        end if;
      end if;

      if self.should_check_well_behaved and num_beats > 0 and wvalid /= '1' then
        self.fail("Burst not well behaved, vwalid was not high during active burst");
      end if;

      if (wvalid and wready) = '1' then
        num_beats := -1;
      end if;

      wait until rising_edge(aclk);
    end loop;
    wait;
  end process;

end architecture;
