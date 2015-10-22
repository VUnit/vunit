-- Run special types 93 package provides types specific to VHDL 93.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.run_types_pkg.all;

package run_special_types_pkg is
  subtype runner_t is runner_state_t;
end package;

package body run_special_types_pkg is
end package body run_special_types_pkg;
