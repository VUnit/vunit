-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Private support package for axi_{read, write}_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;
use work.queue_pkg.all;
use work.message_pkg.all;

package axi_private_pkg is

  type axi_burst_t is record
    id : integer;
    address : integer;
    length : integer;
    size : integer;
    burst_type : axi_burst_type_t;
  end record;

  type axi_slave_t is protected
    procedure init(inbox : inbox_t; data : std_logic_vector);
    impure function is_initialized return boolean;
    impure function get_inbox return inbox_t;

    procedure push_burst(burst : axi_burst_t);
    impure function pop_burst return axi_burst_t;
    impure function has_burst return boolean;
    impure function can_push_burst return boolean;

    procedure set_addr_queue_size(size : positive);

    impure function get_error_queue return queue_t;
    procedure set_error_queue(error_queue : queue_t);
    procedure fail(msg : string);
    procedure check_4kb_boundary(burst : axi_burst_t);
    impure function data_size return integer;
  end protected;

  function decode_burst(axid : std_logic_vector;
                        axaddr : std_logic_vector;
                        axlen : std_logic_vector;
                        axsize : std_logic_vector;
                        axburst : axi_burst_type_t) return axi_burst_t;

  procedure main_loop(variable self : inout axi_slave_t;
                      signal event : inout event_t);

  procedure read_address_channel(variable self : inout axi_slave_t;
                                 signal aclk : in std_logic;
                                 signal axvalid : in std_logic;
                                 signal axready : out std_logic;
                                 signal axid : in std_logic_vector;
                                 signal axaddr : in std_logic_vector;
                                 signal axlen : in std_logic_vector;
                                 signal axsize : in std_logic_vector;
                                 signal axburst : in axi_burst_type_t);

end package;


package body axi_private_pkg is
  type axi_slave_t is protected body
    variable p_is_initialized : boolean := false;
    variable p_inbox : inbox_t;
    variable p_data_size : integer;
    variable p_error_queue : queue_t;

    variable p_addr_queue : queue_t;
    variable p_addr_queue_size : integer;

    procedure init(inbox : inbox_t; data : std_logic_vector) is
    begin
      p_is_initialized := true;
      p_inbox := inbox;
      p_data_size := data'length/8;
      p_addr_queue := allocate;
      set_addr_queue_size(1);
      set_error_queue(null_queue);
    end;

    impure function is_initialized return boolean is
    begin
      return p_is_initialized;
    end;

    impure function get_inbox return inbox_t is
    begin
      return p_inbox;
    end;

    procedure set_addr_queue_size(size : positive) is
    begin
      p_addr_queue_size := size;
    end procedure;

    impure function get_error_queue return queue_t is
    begin
      return p_error_queue;
    end;

    procedure set_error_queue(error_queue : queue_t) is
    begin
      p_error_queue := error_queue;
    end;

    procedure fail(msg : string) is
    begin
      if p_error_queue /= null_queue then
        report msg;
        push_string(p_error_queue, msg);
      else
        report msg severity failure;
      end if;
    end;

    procedure check_4kb_boundary(burst : axi_burst_t) is
      variable first_address, last_address : integer;
    begin
      first_address := burst.address - (burst.address mod data_size); -- Aligned
      last_address := burst.address + burst.size*burst.length - 1;

      if first_address / 4096 /= last_address / 4096 then
        fail("Crossing 4KB boundary");
      end if;
    end procedure;

    procedure push_burst(burst : axi_burst_t) is
    begin
      push(p_addr_queue, burst.id);
      push(p_addr_queue, burst.address);
      push(p_addr_queue, burst.length);
      push(p_addr_queue, burst.size);
      push_boolean(p_addr_queue, burst.burst_type = axi_burst_type_fixed);
    end;

    impure function pop_burst return axi_burst_t is
      variable burst : axi_burst_t;
    begin
      burst.id := pop(p_addr_queue);
      burst.address := pop(p_addr_queue);
      burst.length := pop(p_addr_queue);
      burst.size := pop(p_addr_queue);

      if pop_boolean(p_addr_queue) then
        burst.burst_type := axi_burst_type_fixed;
      else
        burst.burst_type := axi_burst_type_incr;
      end if;

      return burst;
    end;

    impure function has_burst return boolean is
    begin
      return length(p_addr_queue) > 0;
    end;

    impure function can_push_burst return boolean is
    begin
      return length(p_addr_queue) < p_addr_queue_size*5;
    end;

    impure function data_size return integer is
    begin
      return p_data_size;
    end;
  end protected body;

  function decode_burst(axid : std_logic_vector;
                        axaddr : std_logic_vector;
                        axlen : std_logic_vector;
                        axsize : std_logic_vector;
                        axburst : axi_burst_type_t) return axi_burst_t is
    variable burst : axi_burst_t;
  begin
    burst.id := to_integer(unsigned(axid));
    burst.address := to_integer(unsigned(axaddr));
    burst.length := to_integer(unsigned(axlen)) + 1;
    burst.size := 2**to_integer(unsigned(axsize));
    burst.burst_type := axburst;
    return burst;
  end function;

  procedure main_loop(variable self : inout axi_slave_t;
                      signal event : inout event_t) is
    variable msg : msg_t;
    variable reply : reply_t;
    variable msg_type : axi_message_type_t;
  begin
    loop
      recv(event, self.get_inbox, msg, reply);
      msg_type := axi_message_type_t'val(integer'(pop(msg.data)));

      case msg_type is
        when msg_disable_fail_on_error =>
          self.set_error_queue(allocate);
          push_queue_ref(reply.data, self.get_error_queue);
          send_reply(event, reply);

        when msg_set_address_queue_size =>
          self.set_addr_queue_size(pop(msg.data));

      end case;

      recycle(msg);
    end loop;
  end;

  procedure read_address_channel(variable self : inout axi_slave_t;
                                 signal aclk : in std_logic;
                                 signal axvalid : in std_logic;
                                 signal axready : out std_logic;
                                 signal axid : in std_logic_vector;
                                 signal axaddr : in std_logic_vector;
                                 signal axlen : in std_logic_vector;
                                 signal axsize : in std_logic_vector;
                                 signal axburst : in axi_burst_type_t) is
    variable burst : axi_burst_t;
  begin
    assert (axlen'length = 4 or
            axlen'length = 8) report "a{r,w}len must be either 4 (AXI3) or 8 (AXI4)";

    wait until self.is_initialized and rising_edge(aclk);

    loop
      while not self.can_push_burst loop
        wait until rising_edge(aclk);
      end loop;

      axready <= '1';
      wait until (axvalid and axready) = '1' and rising_edge(aclk);
      axready <= '0';

      burst := decode_burst(axid, axaddr, axlen, axsize, axburst);
      self.check_4kb_boundary(burst);

      if burst.burst_type = axi_burst_type_wrap then
        self.fail("Wrapping burst type not supported");
      end if;

      self.push_burst(burst);
    end loop;
  end;
end package body;
