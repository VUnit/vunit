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
use vunit_lib.axi_stream_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_stream_slave_t_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_stream_slave_t_compliance is
begin
  test_runner : process
    constant data_length : natural := 8;

    -- DO NOT modify this line and the lines below.
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
