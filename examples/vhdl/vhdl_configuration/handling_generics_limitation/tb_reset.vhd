-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com
--
-- Description: Instead of having a testbench containing a shared test fixture
-- and then use VHDL configurations to select different test runners implementing
-- different tests one can flip things upside down. Each test become a separate
-- top-level testbench and the shared test fixture is placed in a separate entity
-- imported by each tetbench.

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

entity tb_reset is
  generic(
    runner_cfg : string;
    width : positive
  );
end entity;

architecture tb of tb_reset is
  constant clk_period : time := 10 ns;

  signal reset : std_logic;
  signal clk : std_logic;
  signal d : std_logic_vector(width - 1 downto 0);
  signal q : std_logic_vector(width - 1 downto 0);
begin
  text_fixture_inst : entity work.test_fixture
    generic map(
      width => width,
      clk_period => clk_period
    )
    port map(
      clk => clk,
      reset => reset,
      d => d,
      q => q
    );

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    d <= (others => '1');
    reset <= '1';
    wait until rising_edge(clk);
    wait for 0 ns;
    check_equal(q, 0);

    test_runner_cleanup(runner);
  end process;

end architecture;
