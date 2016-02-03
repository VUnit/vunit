-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

-- From Issue 71. Generic overridden on all hiearchy levels.

library vunit_lib;
use vunit_lib.lang.all;
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

entity tb_no_generic_override is
  generic (
    runner_cfg : runner_cfg_t;
    g_val : boolean);
end entity;

architecture tb of tb_no_generic_override is
  signal s_outp : boolean;
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    assert not g_val;
    assert s_outp;
    test_runner_cleanup(runner);
  end process;

  dut : entity work.bool_driver
    port map ( outp => s_outp );
end architecture;
