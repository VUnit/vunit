-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

-- start_snippet test_runner_entity
entity test_runner is
  generic(
    clk_period : time;
    width : positive;
    nested_runner_cfg : string
  );
  port(
    reset : out std_logic;
    clk : in std_logic;
    d : out std_logic_vector(width - 1 downto 0);
    q : in std_logic_vector(width - 1 downto 0)
  );
end entity;
-- end_snippet test_runner_entity
