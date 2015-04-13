-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

package com_types_pkg is
  type actor_t is record
    id : natural;
  end record actor_t;
  type message_t is record
    sender : actor_t;
    payload : line;
  end record message_t;
  type message_ptr_t is access message_t;
  constant null_actor_c : actor_t := (id => 0);
  type com_status_t is (ok,
                        timeout,
                        null_message_error,
                        unknown_actor_error,
                        unknown_receiver_error,
                        unknown_subscriber_error,
                        unknown_publisher_error,
                        deferred_receiver_error,                        
                        already_a_subscriber_error,
                        not_a_subscriber_error);
  subtype network_t is std_logic;
  constant network_event : std_logic := '1';
  constant idle_network : std_logic := 'Z';
  constant max_timeout_c : time := 1000 hr; -- ModelSim can't handle time'high
end package;
