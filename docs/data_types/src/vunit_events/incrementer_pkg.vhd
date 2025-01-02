-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package incrementer_pkg is
  constant increment_reg_addr : natural := 0;
  constant status_reg_addr : natural := 4;

  -- start_snippet n_samples_field
  subtype n_samples_field is integer range 8 downto 1;
  -- end_snippet n_samples_field
end package incrementer_pkg;
