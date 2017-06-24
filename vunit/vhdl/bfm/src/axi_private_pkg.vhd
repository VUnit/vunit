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
end package;


package body axi_private_pkg is
  type axi_slave_t is protected body
    variable p_inbox : inbox_t;
    variable p_data_size : integer;
    variable p_error_queue : queue_t;

    procedure init(inbox : inbox_t; data : std_logic_vector) is
    begin
      p_inbox := inbox;
      p_data_size := data'length/8;
      set_error_queue(null_queue);
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

end package body;
