-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

-- This package provides wait procedures that will produce a timeout message
-- log entry if they are waiting when the test runner watchdog times out.
-- All procedures are supported by the location preprocessing feature.

use work.logger_pkg.all;
use work.run_types_pkg.all;

package wait_pkg is
  -- Represents the timeout message produced when no user message is given. The
  -- default message provides the status of the wait procedure:
  --
  -- * State of the condition signal if given
  -- * Time remaining on the timeout if specified
  --
  -- For example:
  --
  -- 2000 ps - default    -    INFO - Test runner timeout while blocking on wait_on.
  --                                  Condition is false.
  --                                  1000 ps out of 3000 ps remaining on local timeout.
  constant default_timeout_msg_tag : string := "@$}";

  -- Creates a user defined timeout message consisting of the wait procedure
  -- status and the msg parameter. For example:
  --
  -- 2000 ps - default    -    INFO - Test runner timeout while blocking on wait_on.
  --                                  Waiting on checker completion.
  --                                  Condition is false.
  --                                  1000 ps out of 3000 ps remaining on local timeout.
  function timeout_msg(
    msg : string := "") return string;

  -- This wait_until procedure is equivalent to:
  --
  -- wait on source until condition for timeout;
  --
  -- if initial_eval is false. This is the default behavior. A VHDL wait statement only evaluates the
  -- condition on the next events (changes in signal value) in source or condition. Oftentimes we don't
  -- want to wait for the next event if condition is already true. This behavior can be achieved by
  -- setting initial_eval to true. It is equivalent to:
  --
  -- if not condition then
  --   wait on source until condition for timeout;
  -- end if;
  --
  -- The timeout message is:
  --
  -- * The wait procedure status by default
  -- * The wait procedure status and a user message if the timeout_msg function
  --   is used
  -- * The msg string otherwise (no status)
  --
  -- The timeout message log entry will be done to the logger specified by the parameter with the same name.
  --
  -- For non-boolean source signals you can create a boolean source signal which toggles on every event
  -- in the non-boolean signal:
  --
  -- boolean_source <= boolean_source xor non_boolean_source'event;
  -- wait_until(boolean_source, condition, timeout);
  --
  -- To avoid declaring a new signal boolean_source you can also use the stable attribute:
  --
  -- wait_until(non_boolean_source'stable, condition, timeout);
  --
  -- non_boolean_source'stable is a boolean signal that is true when the source signal has been stable for more
  -- than 0 ns, i.e. it will have a delta-sized false pulse when there is an event in the non-boolean source signal.
  -- This pulse is the event that will trigger the wait procedure. Note that the pulse has
  -- two events (falling and rising edge) when the non-boolean signal has a single event. This is a problem
  -- if the non-boolean signal has several events in adjacent delta cycles (the 'stable pulses will merge into one long pulse), or
  -- if there are two wait procedures a delta cycle apart (the two events in the 'stable pulse will trigger both).
  --
  -- To wait on several signals you need to declare an extra boolean event
  -- signal and then call the concurrent sense procedure with your source
  -- signals, for example
  --
  -- sense(event, source_1, source_2'stable); -- Concurrent call
  -- ...
  -- wait_until(event, condition, timeout; -- In your test case
  --
  -- The sense procedure can also be used when your condition isn't a boolean
  -- signal but rather an expression of a number of signals.
  --
  -- sense(event, source, s1, s2); -- Concurrent call
  -- ...
  -- loop -- In your test case
  --   wait_on(event, timeout);
  --   exit when <expression of signal s1 and s2>
  -- end loop;
  --
  -- sense and wait_on without a condition signal are described below
  procedure wait_until(
    signal source : in boolean;
    signal condition : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant initial_eval : in boolean := false;
    constant logger : in logger_t := default_logger;
    constant msg : in string := default_timeout_msg_tag;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- Equivalent to:
  --
  -- if not (condition and initial_eval) then
  --   wait until condition for timeout;
  -- end if;
  procedure wait_until(
    signal condition : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant initial_eval : in boolean := false;
    constant logger : in logger_t := default_logger;
    constant msg : in string := default_timeout_msg_tag;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- Equivalent to:
  --
  -- if not (source'event and initial_eval) then
  --   wait on source for timeout;
  -- end if;
  procedure wait_on(
    signal source : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant initial_eval : in boolean := false;
    constant logger : in logger_t := default_logger;
    constant msg : in string := default_timeout_msg_tag;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- Equivalent to:
  --
  -- wait for timeout;
  procedure wait_for(
    constant timeout : in delay_length := max_timeout;
    constant logger : in logger_t := default_logger;
    constant msg : in string := default_timeout_msg_tag;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- sense toggles the event signal whenever there is an event in any of the
  -- signals sx.
  procedure sense(
    signal event : inout boolean;
    signal s1, s2 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9 : in boolean);

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 : in boolean);

end package;
