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

package axi_private_pkg is

  type axi_slave_t is protected
    procedure init(data : std_logic_vector);
    impure function data_size return integer;
  end protected;

  type axi_burst_t is record
    id : integer;
    address : integer;
    length : integer;
    size : integer;
    burst_type : axi_burst_type_t;
  end record;

  function decode_burst(axid : std_logic_vector;
                        axaddr : std_logic_vector;
                        axlen : std_logic_vector;
                        axsize : std_logic_vector;
                        axburst : axi_burst_type_t) return axi_burst_t;
  procedure fail(msg : string; error_queue : queue_t);
  procedure check_4kb_boundary(burst : axi_burst_t; data_size : integer; error_queue : queue_t);
end package;


package body axi_private_pkg is
  type axi_slave_t is protected body
    variable p_data_size : integer;

    procedure init(data : std_logic_vector) is
    begin
      p_data_size := data'length/8;
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

  procedure fail(msg : string; error_queue : queue_t) is
  begin
    if error_queue /= null_queue then
      push_string(error_queue, msg);
    else
      report msg severity failure;
    end if;
  end procedure;

  procedure check_4kb_boundary(burst : axi_burst_t; data_size : integer; error_queue : queue_t) is
    variable first_address, last_address : integer;
  begin
    first_address := burst.address - (burst.address mod data_size); -- Aligned
    last_address := burst.address + burst.size*burst.length - 1;

    if first_address / 4096 /= last_address / 4096 then
      fail("Crossing 4KB boundary", error_queue);
    end if;
  end procedure;

end package body;
