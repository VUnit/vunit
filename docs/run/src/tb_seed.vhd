-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.math_real.uniform;

entity tb_seed is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_seed is
  -- start_snippet get_seed_and_runner_cfg
  constant global_seed : string := get_seed(runner_cfg, "Optional salt");
  -- end_snippet get_seed_and_runner_cfg

  -- Placeholder for a non-standard RNG
  procedure init_rng(seed : string) is
  begin
    info("RNG seeded with " & seed);
  end;
begin
  test_runner : process
    variable seed1, seed2 : positive;
    variable a_random_value, another_random_value : real;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that passes") then
        -- start_snippet get_uniform_seed
        get_uniform_seed(seed1, seed2, "Optional salt");

        uniform(seed1, seed2, a_random_value);
        uniform(seed1, seed2, another_random_value);
        -- end_snippet get_uniform_seed

      elsif run("Test that fails") then
        error("Something bad happened");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  -- start_snippet get_seed_wo_runner_cfg
  randomizing_process : process is
    variable local_seed : string_seed_t; -- string_seed_t = string(1 to 16)
  begin
    get_seed(local_seed, salt => randomizing_process'path_name);
    -- end_snippet get_seed_wo_runner_cfg
    wait;
  end process;
end architecture;
