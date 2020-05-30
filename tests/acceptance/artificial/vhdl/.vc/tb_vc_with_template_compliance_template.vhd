-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library lib;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use lib.vc_pkg_with_template.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_vc_with_template_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_vc_with_template_compliance is

  constant vc_h : vc_handle_t := new_vc(
    unspecified => true
  );

  signal a : std_logic;
  signal c, d : std_logic_vector(7 downto 0);
  signal f : std_logic;
  signal j : std_logic;
  signal k, l : std_logic;
  signal m : std_logic;

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity lib.vc_with_template
    generic map(vc_h)
    port map(
      a => a,
      b => open,
      c => c,
      d => d,
      e => open,
      f => f,
      g => open,
      h => open,
      i => open,
      j => j,
      k => k,
      l => l,
      m => m
    );

end architecture;
