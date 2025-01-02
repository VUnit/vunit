-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- start_snippet tb_with_lower_level_control
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_lower_level_control is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_with_lower_level_control is
begin

  test_control: entity work.test_control
    generic map (
      nested_runner_cfg => runner_cfg);

end architecture;
-- end_snippet tb_with_lower_level_control
