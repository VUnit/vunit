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

entity axi_read_slave is
  generic (
    axi_slave : axi_slave_t;
    memory : memory_t);
  port (
    aclk : in std_logic;

    arvalid : in std_logic;
    arready : out std_logic := '0';
    arid : in std_logic_vector;
    araddr : in std_logic_vector;
    arlen : in std_logic_vector;
    arsize : in std_logic_vector;
    arburst : in axi_burst_type_t;

    rvalid : out std_logic := '0';
    rready : in std_logic;
    rid : out std_logic_vector;
    rdata : out std_logic_vector;
    rresp : out axi_resp_t;
    rlast : out std_logic
    );
end entity;

architecture a of axi_read_slave is
  shared variable self : axi_slave_private_t;
  signal initialized : boolean := false;
begin

  control_process : process
  begin
    self.init(axi_slave, rdata);
    initialized <= true;
    main_loop(self, event);
    wait;
  end process;

  axi_process : process
    variable burst : axi_burst_t;
    variable address : integer;
    variable idx : integer;
    variable beats : natural := 0;
  begin
    assert arid'length = rid'length report "arid vs rid data width mismatch";
    -- Initialization
    rid <= (rid'range => '0');
    rdata <= (rdata'range => '0');
    rresp <= (rresp'range => '0');
    rlast <= '0';

    wait on initialized until initialized;

    loop
      if (rready and rvalid) = '1' then
        rvalid <= '0';
        beats := beats - 1;
      end if;

      if (arvalid and arready) = '1' then
        self.push_burst(arid, araddr, arlen, arsize, arburst);
      end if;

      if not self.burst_queue_empty and beats = 0 then
        burst := self.pop_burst;
        beats := burst.length;
        rid <= std_logic_vector(to_unsigned(burst.id, rid'length));
        rresp <= axi_resp_okay;
        address := burst.address;
      end if;

      if beats > 0 and (rvalid = '0' or rready = '1') then
        rvalid <= '1';
        for j in 0 to burst.size-1 loop
          idx := (address + j) mod self.data_size;
          rdata(8*idx+7 downto 8*idx) <= std_logic_vector(to_unsigned(read_byte(memory, address+j), 8));
        end loop;

        if burst.burst_type = axi_burst_type_incr then
          address := address + burst.size;
        end if;

        if beats = 1 then
          rlast <= '1';
        else
          rlast <= '0';
        end if;
      end if;

      if self.should_stall_address_channel or self.burst_queue_full then
        arready <= '0';
      else
        arready <= '1';
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

      if arvalid = '1' then
        len       := to_integer(unsigned(arlen));
        num_beats_now := num_beats + len + 1;
      end if;

      -- Always keep track of num_beats such that the well behaved check can be enabled at any time
      if (arvalid and arready) = '1' then
        size      := 2**to_integer(unsigned(arsize));
        num_beats := num_beats_now;

        if self.should_check_well_behaved and size /= self.data_size and len /= 0 then
          self.fail("Burst not well behaved, axi size = " & to_string(size) & " but bus data width allows " & to_string(self.data_size));
        end if;
      end if;

      if self.should_check_well_behaved and num_beats_now > 0 and rready /= '1' then
        self.fail("Burst not well behaved, rready was not high during active burst");
      end if;

      if (rready and rvalid) = '1' then
        num_beats := -1;
      end if;

      wait until rising_edge(aclk);
    end loop;
    wait;
  end process;

end architecture;
