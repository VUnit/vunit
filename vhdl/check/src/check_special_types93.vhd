-- Check types specific to the VHDL 93 implementation.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;
use work.check_types_pkg.all;

package check_special_types_pkg is
  type boolean_vector is array (natural range <>) of boolean;

  type checker_t is record
    default_log_level : log_level_t;
    stat              : checker_stat_t;
    logger            : logger_t;
  end record;
end package;

package body check_special_types_pkg is
end package body check_special_types_pkg;
