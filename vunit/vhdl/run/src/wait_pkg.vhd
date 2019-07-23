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

end package;
