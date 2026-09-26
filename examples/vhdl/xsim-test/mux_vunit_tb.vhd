-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

--! Standard library.
library ieee;
--! Logic elements.
use ieee.std_logic_1164.all;
--! Arithmetic functions.
use ieee.numeric_std.all;
--! Others
library std;
use std.textio.all;
--! VUnit
library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.core_pkg;
use vunit_lib.string_ops.all;

library src_lib;
use src_lib.adder;

entity mux_tb is
  --vunit
  generic (g_DATA_WIDTH : integer := 8; runner_cfg : string);
end;

architecture bench of mux_tb is
    component adder
    generic(DATA_WIDTH : positive := 5);
    port (
      clk : in  std_logic;
      a   : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
      b   : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
      x   : out std_logic_vector(g_DATA_WIDTH-1 downto 0)
    );
  end component;
  -- clock period
  constant clk_period : time := 5 ns;
  -- Signal ports
  signal clk: std_logic := '0';
  signal a: std_logic_vector(g_DATA_WIDTH-1 downto 0);
  signal b: std_logic_vector(g_DATA_WIDTH-1 downto 0);
  signal x: std_logic_vector(g_DATA_WIDTH-1 downto 0) ;
begin

  uut: adder
    generic map (DATA_WIDTH => g_DATA_WIDTH)
    port map ( clk => clk,
               a  => a,
               b  => b,
               x  => x );

  main : process
    variable ff : boolean;
  begin

    test_runner_setup(runner, runner_cfg);
    if run("Test_1") then
      report("g_DATA_WIDTH=" & integer'image(g_DATA_WIDTH));
      wait for 10*clk_period;
      report("-----> End.");
      wait for 10*clk_period;
    end if;
    test_runner_cleanup(runner);

  end process;

  clk_process :process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

end;
