-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.log_types_pkg.all;
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
      if run("Verify that joining a single path returns that path") then
        check_equal(join("some_path"), "some_path");
      elsif run("Verify that joining an empty path with a second path returns the second path") then
        check_equal(join("", "some_path"), "some_path");
      elsif run("Verify the joining of two paths") then
        check_equal(join("foo", "bar"), "foo/bar");
      elsif run("Verify that a separator ending the first path is ignored") then
        check_equal(join("foo/", "bar"), "foo/bar");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process test_runner;

  test_runner_watchdog(runner, 1 us);
end test_fixture;
