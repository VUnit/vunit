-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.textio.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;

library lib;

entity tb_top is
  generic (runner_cfg : runner_cfg_t);
end entity;

architecture tb of tb_top is
  signal clk       : std_logic := '0';
  signal in_valid  : std_logic := '0';
  signal in_data   : std_logic_vector(7 downto 0) := (others => '0');
  signal out_valid : std_logic;
  signal out_data  : std_logic_vector(7 downto 0);

  constant num_data : integer := 128;
  signal start, done : boolean := false;
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    wait for 100 ns;
    start <= true;
    wait until done;
    test_runner_cleanup(runner);
  end process;

  stimuli : process
  begin
    wait until start;
    wait until rising_edge(clk);
    for i in 1 to num_data loop
      in_valid <= '1';
      in_data <= std_logic_vector(to_unsigned(i, in_data'length));
      wait until rising_edge(clk);
      in_valid <= '0';
    end loop;
    wait;
  end process;

  data_check : process
  begin
    wait until start;
    wait until rising_edge(clk);
    for i in 1 to num_data loop
      wait until out_valid = '1' and rising_edge(clk);
      check_equal(unsigned(out_data), i);
    end loop;
    done <= true;
    wait;
  end process;

  clk <= not clk after 1 ns;
  dut : entity lib.top
    port map (
      clk       => clk,
      in_valid  => in_valid,
      in_data   => in_data,
      out_valid => out_valid,
      out_data  => out_data);

  test_runner_watchdog(runner, 1 ms);
end architecture;
