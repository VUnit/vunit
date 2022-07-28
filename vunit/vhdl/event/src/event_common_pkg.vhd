-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- This packages provides functionality common to both user events and the
-- basic events used within the VUnit implementation.

library ieee;
use ieee.std_logic_1164.all;

package event_common_pkg is
  subtype any_event_t is std_logic_vector;

  -- Notify all event observers by activating the event for one delta cycle.
  procedure notify(signal event : inout any_event_t);

  -- Return true if event is active in current delta cycle, false otherwise.
  impure function is_active(signal event : any_event_t) return boolean;

  -- Private to VUnit
  constant p_event_idx : natural := 0;
  constant p_identifier_idx : natural := p_event_idx + 1;

  constant p_triggered_event : std_logic := '1';
  constant p_no_event : std_logic := 'Z';
end package;

package body event_common_pkg is
  procedure notify(signal event : inout any_event_t) is
  begin
    if event(event'left + p_event_idx) /= p_triggered_event then
      event(event'left + p_event_idx) <= p_triggered_event;
      wait until event(event'left + p_event_idx) = p_triggered_event;
      event(event'left + p_event_idx) <= p_no_event;
    end if;
  end;

  impure function is_active(signal event : any_event_t) return boolean is
  begin
    return event(event'left + p_event_idx) = p_triggered_event;
  end;


end package body;
