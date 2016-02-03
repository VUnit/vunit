-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

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

entity tb_with_generic_config is
  generic (
    runner_cfg : runner_cfg_t;
    output_path : string;
    set_generic : string := "default";
    config_generic : string := "default");
end entity;

architecture tb of tb_with_generic_config is
begin
  test_runner : process
    file fptr : text;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test 0") then
        assert set_generic = "set-for-entity";
        assert config_generic = "default";

      elsif run("Test 1") then
        assert set_generic = "set-for-entity";
        assert config_generic = "set-from-config";

      elsif run("Test 2") then
        assert set_generic = "set-for-test";
        assert config_generic = "default";

      elsif run("Test 3") then
        assert set_generic = "set-for-test";
        assert config_generic = "set-from-config";

      elsif run("Test 4") then
        assert set_generic = "set-from-config";
        assert config_generic = "set-from-config";
        file_open(fptr, output_path & "post_check.txt", write_mode);
        write(fptr, string'("Test 4 was here"));
        file_close(fptr);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 50 ns);
end architecture;
