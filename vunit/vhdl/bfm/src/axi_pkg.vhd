-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.message_pkg.all;

package axi_pkg is
  subtype axi_resp_t is std_logic_vector(1 downto 0);
  constant axi_resp_ok : axi_resp_t := "00";

  subtype axi_burst_type_t is std_logic_vector(1 downto 0);
  constant axi_burst_type_fixed : axi_burst_type_t := "00";
  constant axi_burst_type_incr : axi_burst_type_t := "01";
  constant axi_burst_type_wrap : axi_burst_type_t := "10";

  subtype axi4_len_t is std_logic_vector(7 downto 0);
  subtype axi4_size_t is std_logic_vector(2 downto 0);


  type axi_message_type_t is (
    msg_disable_fail_on_error,
    msg_set_address_queue_size);

  -- Disables failure on internal errors that are instead pushed to an error queue
  -- Used for testing the BFM error messages
  procedure disable_fail_on_error(signal event : inout event_t; inbox : inbox_t; variable error_queue : inout queue_t);

  procedure set_addr_queue_size(signal event : inout event_t; inbox : inbox_t; size : positive);

end package;

package body axi_pkg is
  procedure disable_fail_on_error(signal event : inout event_t; inbox : inbox_t; variable error_queue : inout queue_t) is
    variable msg : msg_t;
    variable reply : reply_t;
  begin
    msg := allocate;
    push(msg.data, axi_message_type_t'pos(msg_disable_fail_on_error));
    send(event, inbox, msg, reply);
    recv_reply(event, reply);
    error_queue := pop_queue_ref(reply.data);
    recycle(reply);
  end;

  procedure set_addr_queue_size(signal event : inout event_t; inbox : inbox_t; size : positive) is
    variable msg : msg_t;
    variable reply : reply_t;
  begin
    msg := allocate;
    push(msg.data, axi_message_type_t'pos(msg_set_address_queue_size));
    push(msg.data, size);
    send(event, inbox, msg);
  end;
end package body;
