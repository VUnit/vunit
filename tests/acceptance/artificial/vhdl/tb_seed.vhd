-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- This attribute should be ignored when VHDL assert stop level is used
-- vunit: fail_on_warning

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_seed is
  generic (
    runner_cfg : string;
    expected_seed : string := ""
  );
end entity;

architecture tb of tb_seed is
  constant seed : string := get_seed(runner_cfg);
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    show(display_handler, pass);

    while test_suite loop
      if expected_seed = "" then
        -- Not expecting the seed derived from --seed=0123456789abcdef
        check(seed /= "2e373913e5ad677d");
      else
        check_equal(seed, expected_seed);
      end if;

      if run("test_1") then
        -- Not expecting the seed derived from --seed=repeat
        check_implication(expected_seed = "", seed /= "ffa08cd9489aad14");
      elsif run("test_2") then
        -- Not expecting the seed derived from --seed=repeat
        check_implication(expected_seed = "", seed /= "9a292b3679afd081");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
