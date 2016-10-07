-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;

package check_types_pkg is
  type edge_t is (rising_edge, falling_edge, both_edges);
  type trigger_event_t is (first_pipe, first_no_pipe, penultimate);
  type checker_stat_t is record
    n_checks : natural;
    n_failed : natural;
    n_passed : natural;
  end record;

  type checker_cfg_t is record
    default_level : log_level_t;
    logger_cfg    : logger_cfg_t;
  end record;

  type checker_cfg_export_t is record
    default_level : log_level_t;
    logger_cfg    : logger_cfg_export_t;
  end record;
end package;
