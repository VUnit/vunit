-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- This package, together with event_common_pkg, provides a user event
-- notification system.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.event_private_pkg.all;
use work.event_common_pkg.all;
use work.string_ops.all;
use work.logger_pkg.all;
use work.string_ptr_pkg.all;
use work.id_pkg.all;
use work.integer_vector_ptr_pkg.all;

package event_pkg is
  constant event_length : positive := 33;
  subtype event_t is any_event_t(0 to event_length - 1);
  constant null_event : event_t := (others => 'X');

  constant event_pkg_logger : logger_t := get_logger("vunit_lib:event_pkg:logger");

  -- Create a new user event. The result of the call MUST
  -- be assigned to a SIGNAL. Results in an error if an event
  -- has already been created for the given id.
  impure function new_event(id : id_t) return event_t;

  -- Return true if an event for the given id exists, false otherwise
  impure function has_event(id : id_t) return boolean;

  impure function id(signal event : event_t) return id_t;
  impure function name(signal event : any_event_t) return string;
  impure function full_name(signal event : any_event_t) return string;

  -- Return true if event is active in current delta cycle, false otherwise. If true it will
  -- also produce a message. The function supports message decoration and will add
  -- "Event <name of event> activated" before the custom message.
  --
  -- is_active_msg is typically used in wait statements to handle and report exceptions to the
  -- expected program flow. For example,
  --
  -- wait until some_test_condition or is_active_msg(test_runner_watchdog_timeout, decorate("while waiting for some test condition");
  --
  -- is_active_msg supports log location which means that if VHDL-2019 is used, or if location preprocessing is enabled, the following
  -- is usually sufficient for debugging:
  --
  -- wait until some_test_condition or is_active_msg(test_runner_watchdog_timeout)
  --
  -- The caller can also provide a custom logger.
  impure function is_active_msg(
    signal event : any_event_t;
    constant msg : in string := decorate_tag;
    constant logger : in logger_t := event_pkg_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := ""
  ) return boolean;

end package;

package body event_pkg is
  constant event_ids : integer_vector_ptr_t := new_integer_vector_ptr;

  impure function has_event(id : id_t) return boolean is
    constant id_as_integer : integer := to_integer(id);
  begin
    for idx in 0 to length(event_ids) - 1 loop
      if get(event_ids, idx) = id_as_integer then
        return true;
      end if;
    end loop;

    return false;
  end;

  impure function new_event(id : id_t) return event_t is
    variable ret_val : event_t;
  begin
    if has_event(id) then
      error(event_pkg_logger, "Event already created for " & full_name(id) & ".");
      return null_event;
    end if;

    resize(event_ids, length(event_ids) + 1);
    set(event_ids, length(event_ids) - 1, to_integer(id));

    ret_val(p_event_idx) := p_no_event;
    ret_val(p_identifier_idx to ret_val'high) := std_logic_vector(to_unsigned(to_integer(id), ret_val'high - p_identifier_idx + 1));

    return ret_val;
  end;

  impure function id(signal event : event_t) return id_t is
  begin
    return to_id(to_integer(unsigned(event(event'left + p_identifier_idx to event'high))));
  end;

  impure function name(signal event : any_event_t) return string is
  begin
    if event'length = event_length then
      return name(to_id(to_integer(unsigned(event(event'left + p_identifier_idx to event'high)))));
    end if;

    return basic_event_name(event);
  end;

  impure function full_name(signal event : any_event_t) return string is
  begin
    if event'length = event_length then
      return full_name(to_id(to_integer(unsigned(event(event'left + p_identifier_idx to event'high)))));
    end if;

    return basic_event_full_name(event);
  end;

  impure function create_event_msg(msg : string := ""; signal event : any_event_t) return string is
    function append_event_name(msg, event_name : string) return string is
    begin
      if event_name = "" then
        return "Event activated" & msg;
      else
        return "Event " & event_name & " activated" & msg;
      end if;
    end function;
  begin
    if not is_decorated(msg) then
      return msg;
    else
      return append_event_name(undecorate(msg), full_name(event));
    end if;
  end;

  impure function is_active_msg(
    signal event : any_event_t;
    constant msg : in string := decorate_tag;
    constant logger : in logger_t := event_pkg_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := ""
  ) return boolean is
    constant event_msg : string := create_event_msg(msg, event);
  begin
    if not is_active(event) then
      return false;
    end if;

    if event_msg /= "" then
      info(logger, event_msg, line_num => line_num, file_name => file_name, path_offset => path_offset + 1);
    end if;

    return true;
  end;

end package body;
