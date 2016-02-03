-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

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

entity tb_generated is
  generic (
    runner_cfg : string := runner_cfg_default;
    output_path : string;
    data_width : natural;
    sign : boolean;
    message : string);
end entity;

architecture a of tb_generated is
begin
  main : process
    procedure dump_generics is
      file fwrite : text;
      variable l : line;
    begin
      file_open(fwrite, output_path & "/" & "generics.txt", write_mode);
      write(l, to_string(data_width) & ", " & to_string(sign));
      writeline(fwrite, l);
      file_close(fwrite);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test 1") then
        assert message = "set-for-entity";
        dump_generics;
      elsif run("Test 2") then
        assert message = "set-for-test";
        dump_generics;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 10 ms);
end architecture;
