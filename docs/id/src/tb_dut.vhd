-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_dut is
  generic(
    runner_cfg : string);
end entity;

-- start_snippet tb_dut
architecture vunit_style of tb_dut is
  -- start_folding -- Declarations
  signal d : bit := '0';
  signal q : bit;
  -- end_folding -- Declarations
begin
  stimuli : process
  begin
    -- start_folding ...
    test_runner_setup(runner, runner_cfg);

    for iter in 1 to 5 loop
      d <= not d;
      wait for 10 ns;
    end loop;

    test_runner_cleanup(runner);
    -- end_folding ...
  end process;

  my_dut : entity work.dut
    port map(
      -- start_folding ...
      d => d,
      q => q
      -- end_folding ...
    );

  vc_x : entity work.verification_component_x
    generic map(
      -- start_folding name => vc_x'path_name
      name => tb_dut'path_name & "vc_x:"
      -- end_folding name => vc_x'path_name
    )
    port map(
      -- start_folding ...
      q => q
      -- end_folding ...
    );

  vc_y : entity work.verification_component_y
    generic map(
      -- start_folding name => vc_y'path_name
      name => tb_dut'path_name & "vc_y:"
      -- end_folding name => vc_y'path_name
    )
    port map(
      -- start_folding ...
      q => q
      -- end_folding ...
    );
end architecture;
-- end_snippet tb_dut
