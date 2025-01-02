-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_composite_generics is
  generic (
    encoded_tb_cfg : string;
    runner_cfg : string);
end tb_composite_generics;

architecture tb of tb_composite_generics is
  type tb_cfg_t is record
    image_width     : positive;
    image_height    : positive;
    dump_debug_data : boolean;
  end record tb_cfg_t;

  impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
  begin
    return (image_width => positive'value(get(encoded_tb_cfg, "image_width")),
            image_height => positive'value(get(encoded_tb_cfg, "image_height")),
            dump_debug_data => boolean'value(get(encoded_tb_cfg, "dump_debug_data")));
  end function decode;

  constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

  signal dumping_done : boolean := not tb_cfg.dump_debug_data;
  signal data_valid : std_logic := '1';
  signal clk : std_logic := '0';
  constant clk_period : time := 2 ns;
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test 1") then
        check_equal(tb_cfg.image_width/4, tb_cfg.image_height/3, "Failed dummy test");
      end if;
    end loop;

    if not dumping_done then
      wait until dumping_done;
    end if;

    test_runner_cleanup(runner);
    wait;
  end process test_runner;

  clk <= not clk after clk_period/2;

  dump_debug_data: if tb_cfg.dump_debug_data generate
    process is
    begin
      for y in 0 to tb_cfg.image_height - 1 loop
        for x in 0 to tb_cfg.image_width - 1 loop
          wait until rising_edge(clk) and data_valid = '1';
          debug("Dumping tons of debug data");
        end loop;
      end loop;

      dumping_done <= true;
      wait;
    end process;
  end generate dump_debug_data;
end;
