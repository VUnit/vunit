-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use vunit_lib.signal_checker_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_std_logic_checker_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_std_logic_checker_compliance is
  constant signal_checker : signal_checker_t := new_signal_checker;

  signal value : std_logic_vector(7 downto 0);
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.std_logic_checker
    generic map(signal_checker)
    port map(
      value => value
    );

end architecture;
