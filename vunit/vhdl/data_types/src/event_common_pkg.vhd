-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- This packages provides functionality common to both user events and the
-- basic events used within the VUnit implementation.

library ieee;
use ieee.std_logic_1164.all;

use work.types_pkg.all;

package event_common_pkg is
  subtype any_event_t is std_logic_vector;

  -- Notify all event observers by activating the event(s) for one delta cycle.
  -- An n_delta_cycles number of delta cycles are added after activating the
  -- event(s) before the returning from the procedures. The default value is
  -- such that any process waiting for/blocking on the event(s) can perform actions
  -- that will complete before any actions performed by the caller of notify,
  -- after returning from the notify call. This is under the assumption that the
  -- unblocked process performs its actions immediately without any additional
  -- wait statements, not even a delta cycle delay. The caller of notify must not
  -- make any assumption on the default value other than what has been described.
  -- The value may change without notice to support new use cases. If a special value is
  -- needed, it must be specified explicitly.
  constant default_n_delta_cycles : natural;
  procedure notify(signal event : inout any_event_t; n_delta_cycles : natural := default_n_delta_cycles);
  procedure notify(signal event1, event2 : inout any_event_t; n_delta_cycles : natural := default_n_delta_cycles);

  -- Return true if event is active in current delta cycle, false otherwise.
  impure function is_active(signal event : any_event_t) return boolean;

  -- Private to VUnit
  constant p_event_idx : natural := 0;
  constant p_identifier_idx : natural := p_event_idx + 2;

  constant p_active_event : std_logic := '1';
  constant p_inactive_event : std_logic_vector := "ZZ";
end package;

package body event_common_pkg is
  impure function is_active(signal event : any_event_t) return boolean is
  begin
    return event(event'left + p_event_idx to event'left + p_event_idx + 1) /= p_inactive_event;
  end;

  procedure activate(signal event : inout any_event_t) is
  begin
    if event(event'left + p_event_idx) = p_active_event then
      event(event'left + p_event_idx + 1) <= p_active_event;
    else
      event(event'left + p_event_idx) <= p_active_event;
    end if;
  end;

  procedure inactivate(signal event : inout any_event_t) is
  begin
    event(event'left + p_event_idx to event'left + p_event_idx + 1) <= p_inactive_event;
  end;

  constant default_n_delta_cycles : natural := 1;
  procedure notify(signal event : inout any_event_t; n_delta_cycles : natural := default_n_delta_cycles) is
  begin
    activate(event);
    wait until is_active(event);
    inactivate(event);

    for iter in 1 to n_delta_cycles loop
      wait for 0 ns;
    end loop;
  end;

  procedure notify(signal event1, event2 : inout any_event_t; n_delta_cycles : natural := default_n_delta_cycles) is
  begin
    activate(event1);
    activate(event2);
    wait until is_active(event1) and is_active(event2);
    inactivate(event1);
    inactivate(event2);

    for iter in 1 to n_delta_cycles loop
      wait for 0 ns;
    end loop;
  end;

end package body;
