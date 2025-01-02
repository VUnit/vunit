-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- Description: This is an example of a testbench using separate architectures
-- of a test runner entity to define different tests. This is a structure
-- found in OSVVM-native testbenches

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

entity tb_selecting_test_runner_with_vhdl_configuration is
  generic(
    runner_cfg : string;
    width : positive
  );
end entity;

architecture tb of tb_selecting_test_runner_with_vhdl_configuration is
  constant clk_period : time := 10 ns;

  signal reset : std_logic;
  signal clk : std_logic := '0';
  signal d : std_logic_vector(width - 1 downto 0);
  signal q : std_logic_vector(width - 1 downto 0);

  component test_runner is
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
  end component;

  component dff is
    generic(
      width : positive := width
    );
    port(
      clk : in std_logic;
      reset : in std_logic;
      d : in std_logic_vector(width - 1 downto 0);
      q : out std_logic_vector(width - 1 downto 0)
    );
  end component;

begin
  -- start_snippet test_runner_component_instantiation
  test_runner_inst : component test_runner
    generic map(
      clk_period => clk_period,
      width => width,
      nested_runner_cfg => runner_cfg
    )
    port map(
      reset => reset,
      clk => clk,
      d => d,
      q => q
    );
  -- end_snippet test_runner_component_instantiation

  test_fixture : block is
  begin
    clk <= not clk after clk_period / 2;

    dut : component dff
      generic map(
        width => width
      )
      port map(
        clk => clk,
        reset => reset,
        d => d,
        q => q
      );
  end block;
end architecture;
