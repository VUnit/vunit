-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;
use work.axi_slave_pkg.all;
use work.axi_slave_private_pkg.all;
use work.com_pkg.net;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.memory_pkg.all;
use work.queue_pkg.all;

entity axi_write_slave is
  generic (
    axi_slave : axi_slave_t;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X'
  );
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

  constant data_vector_length : natural := max_axi4_burst_length * wdata'length;
  constant data_pool : integer_vector_ptr_pool_t := new_integer_vector_ptr_pool;

  type burst_data_t is record
    length : natural;
    address : integer_vector_ptr_t;
    data : integer_vector_ptr_t;
  end record;

  procedure push_burst_data(queue : queue_t; variable burst_data : inout burst_data_t) is
  begin
     push_integer(queue, burst_data.length);
     push_integer_vector_ptr_ref(queue, burst_data.address);
     push_integer_vector_ptr_ref(queue, burst_data.data);
  end;

  impure function pop_burst_data(queue : queue_t) return burst_data_t is
    variable burst_data : burst_data_t;
  begin
    burst_data.length := pop_integer(queue);
    burst_data.address := pop_integer_vector_ptr_ref(queue);
    burst_data.data := pop_integer_vector_ptr_ref(queue);
    return burst_data;
  end;

  impure function new_burst_data return burst_data_t is
  begin
    return (length => 0,
            address => new_integer_vector_ptr(data_pool, min_length => data_vector_length),
            data => new_integer_vector_ptr(data_pool, min_length => data_vector_length));
  end;

  procedure recycle(variable burst_data : inout burst_data_t) is
  begin
    recycle(data_pool, burst_data.address);
    recycle(data_pool, burst_data.data);
  end;

begin

  control_process : process
  begin
    self.init(axi_slave, write_slave, 2**awid'length-1, wdata);
    initialized <= true;
    main_loop(self, net);
    wait;
  end process;

  axi_process : process

    procedure drive_b_invalid is
    begin
      if drive_invalid then
        bid <= (bid'range => drive_invalid_val);
        bresp <= (bresp'range => drive_invalid_val);
      end if;
    end procedure;

    procedure record_input_data(variable input_data : inout burst_data_t;
                                address : natural; byte : natural) is
      variable ignored : boolean;
    begin
      if not check_address(axi_slave.p_memory, address, reading => false, check_permissions => true) then
        return;
      end if;

      set(input_data.address, input_data.length, address);
      set(input_data.data, input_data.length, byte);
      input_data.length := input_data.length + 1;

      ignored := check_write_data(axi_slave.p_memory, address, byte);
    end;

    procedure write_data_to_memory(input_data_queue : queue_t) is
      variable burst_data : burst_data_t;
    begin
      burst_data := pop_burst_data(input_data_queue);
      for i in 0 to burst_data.length-1 loop
        write_byte_unchecked(axi_slave.p_memory, get(burst_data.address, i), get(burst_data.data, i));
      end loop;
      recycle(burst_data);
    end;

    variable resp_burst, input_burst, burst : axi_burst_t;
    variable address, aligned_address : integer;
    variable beats : natural := 0;
    variable input_data : burst_data_t;
    constant input_data_queue : queue_t := new_queue;

    variable response_time : time;
    variable has_response_time : boolean := false;
  begin
    assert awid'length = bid'length report "awid vs wid data width mismatch";
    assert (awlen'length = 4 or
            awlen'length = 8) report "awlen must be either 4 (AXI3) or 8 (AXI4)";

    -- Initialization
    drive_b_invalid;

    wait on initialized until initialized;

    loop
      if bready = '1' then
        bvalid <= '0';
        drive_b_invalid;
      end if;

      if (awvalid and awready) = '1' then
        input_burst := self.create_burst(awid, awaddr, awlen, awsize, awburst);
        self.push_burst(input_burst);
      end if;

      if (wvalid and wready) = '1' then
        if (wlast = '1') /= (beats = 1) then
          self.fail("Expected wlast='1' on last beat of burst " & describe_burst(burst) &
                    " with length " & to_string(burst.length) &
                    " starting at address " & to_string(burst.address));
        end if;

        aligned_address := address - (address mod self.data_size);
        for j in 0 to self.data_size-1 loop
          if wstrb(j) = '1' then
            record_input_data(input_data, aligned_address+j, to_integer(unsigned(wdata(8*j+7 downto 8*j))));
          end if;
        end loop;

        if burst.burst_type = axi_burst_type_incr then
          address := address + burst.size;
        end if;

        beats := beats - 1;
        if beats = 0 then
          self.push_random_response_time;
          self.finish_burst(burst);
          self.push_resp(burst);
          push_burst_data(input_data_queue, input_data);
        end if;
      end if;

      if not (self.burst_queue_empty or beats > 0) then
        input_data := new_burst_data;
        burst := self.pop_burst;
        address := burst.address;
        beats := burst.length;
      end if;

      if not self.resp_queue_empty and (bvalid = '0' or bready = '1') and not self.should_stall_write_response then

        if not has_response_time then
          has_response_time := true;
          response_time := self.pop_response_time;
        end if;

        if has_response_time and response_time <= now then
          has_response_time := false;
          resp_burst := self.pop_resp;
          write_data_to_memory(input_data_queue);
          bvalid <= '1';
          bid <= std_logic_vector(to_unsigned(resp_burst.id, bid'length));
          bresp <= axi_resp_okay;
        end if;
      end if;

      if beats > 0 and not (beats = 1 and self.resp_queue_full) and not self.should_stall_data then
        wready <= '1';
      else
        wready <= '0';
      end if;

      if self.should_stall_address or self.burst_queue_full then
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
        self.fail("Burst not well behaved, wvalid was not high during active burst");
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
