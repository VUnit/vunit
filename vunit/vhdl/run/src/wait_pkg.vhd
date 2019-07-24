-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

-- This package provides wait procedures that will produce a log entry if they
-- are waiting when the test runner watchdog times out. All procedures are
-- supported by the location preprocessing feature.

use work.logger_pkg.all;
use work.run_types_pkg.all;

package wait_pkg is

  -- Equivalent to:
  --
  -- wait on source until condition for timeout;
  --
  -- The log entry will be done to the logger specified by the parameter with the same name.
  --
  -- For non-boolean source signals the stable attribute can be used.
  --
  -- wait on source'stable until condition for timeout;
  --
  -- source'stable is a boolean signal that is true when the source signal has been stable for more
  -- than 0 ns, i.e. it will have a delta pulse when there is an event in the source signal.
  --
  -- To wait on several signals you need to declare an extra boolean event
  -- signal and then call the concurrent sense procedure with your source
  -- signals, for example
  --
  -- sense(event, source_1, source_2'stable); -- Concurrent call
  -- ...
  -- wait on event until condition for timeout; -- In your test case
  --
  -- The sense procedure can also be used when your condition isn't a boolean
  -- signal but rather an expression of a number of signals.
  --
  -- sense(event, source, s1, s2); -- Concurrent call
  -- ...
  -- while not <expression of signal s1 and s2> loop -- In your test case
  --   wait_on(event, timeout);
  -- end loop;
  --
  -- sense and wait_on without a condition signal is declared below
  --
  procedure wait_on(
    signal source      : in boolean;
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  -- Equivalent to:
  --
  -- wait on source for timeout;
  --
  procedure wait_on(
    signal source      : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  -- Equivalent to:
  --
  -- wait for timeout;
  --
  procedure wait_for(
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  -- Equivalent to:
  --
  -- wait until condition for timeout;
  --
  procedure wait_until(
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

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
