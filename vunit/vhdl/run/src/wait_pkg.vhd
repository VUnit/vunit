-- This package provides wait procedures that will produce a log if they
-- are waiting when the test runner watchdog times out.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.run_types_pkg.all;

package wait_pkg is

  procedure wait_on(
    signal source      : in boolean;
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  procedure wait_on(
    signal source      : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  procedure wait_for(
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

  procedure wait_until(
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "");

end package;
