-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.path.all;

entity tb_path is
  generic (
    runner_cfg : string);
end entity tb_path;

architecture test_fixture of tb_path is
begin
  test_runner: process is
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test joining paths") then
        check_equal(join(""), "");
        check_equal(join("", "p2"), "p2");
        check_equal(join("p1"), "p1");
        check_equal(join("p1", p5 => "p5", p10 => "p10"), "p1/p5/p10");
        check_equal(join("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9", "p10"),
                         "p1/p2/p3/p4/p5/p6/p7/p8/p9/p10");
      elsif run("Verify that a separator ending a path component is ignored") then
        check_equal(join("/p1/", "p2/", "p3", "/", "p4"), "/p1/p2/p3/p4");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process test_runner;

  test_runner_watchdog(runner, 1 us);
end test_fixture;
