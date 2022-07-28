-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- This packages provides a basic event notification system only to be used within VUnit
-- at places where the number of external package dependencies should be kept low.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.event_common_pkg.all;

package event_private_pkg is
  constant basic_event_length : positive := 4;
  subtype basic_event_t is any_event_t(0 to basic_event_length - 1);

  -- All basic events have a predefined type..
  type basic_event_type_t is (vunit_stop, vunit_error, test_runner_timeout, com_network, test_runner_state, test_runner_timeout_update);

  -- Create a new basic event.
  impure function new_basic_event(basic_event_type : basic_event_type_t) return basic_event_t;

  function basic_event_name(signal basic_event : basic_event_t) return string;
  function basic_event_full_name(signal basic_event : basic_event_t) return string;
end package;

package body event_private_pkg is

  impure function new_basic_event(basic_event_type : basic_event_type_t) return basic_event_t is
    variable ret_val : basic_event_t;
  begin
    ret_val(p_event_idx) := p_no_event;
    ret_val(p_identifier_idx to ret_val'high) := std_logic_vector(to_unsigned(basic_event_type_t'pos(basic_event_type), ret_val'high - p_identifier_idx + 1));

    return ret_val;
  end;

  function basic_event_name(signal basic_event : basic_event_t) return string is
  begin
    return basic_event_type_t'image(basic_event_type_t'val(to_integer(unsigned(basic_event(basic_event'left + p_identifier_idx to basic_event'high)))));
  end;

  function basic_event_full_name(signal basic_event : basic_event_t) return string is
  begin
    return "vunit_lib:event_pkg:" & basic_event_name(basic_event);
  end;

end package body;
