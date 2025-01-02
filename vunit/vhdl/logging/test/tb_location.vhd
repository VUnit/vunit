-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.log_levels_pkg.all;
use work.logger_pkg.all;

entity tb_location is
  generic(
    runner_cfg : string;
    vhdl_2019 : boolean := false
  );
end entity;

architecture tb of tb_location is
begin
  main : process
    procedure print_vhdl_2019_style(str : string) is
    begin
      info(str, path_offset => 1);
    end;

    procedure print_pre_vhdl_2019_style(str : string; line_num : natural := 0; file_name : string := "") is
    begin
      info(str, line_num => line_num, file_name => file_name);
    end;

    procedure check_log(line_num : natural; expect_location : boolean) is
    begin
      if expect_location then
        check_only_log(default_logger, "message", info, 0 ns, line_num, "tb_location.vhd");
      else
        check_only_log(default_logger, "message", info, 0 ns);
      end if;
    end;
  begin
    test_runner_setup(runner, runner_cfg);

    mock(default_logger);
    while test_suite loop
      if run("Test that correct location is logged") then
        info("message");
        check_log(47, expect_location => vhdl_2019);

      elsif run("Test that correct location is logged when calling lower-level log procedure") then
        info(default_logger, "message");
        check_log(51, expect_location => vhdl_2019);

      elsif run("Test that correct location is logged for custom log procedure using path_offset") then
        print_vhdl_2019_style("message");
        check_log(55, expect_location => vhdl_2019);

      elsif run("Test that correct location is logged for custom log procedure using line_num and file_name") then
        print_pre_vhdl_2019_style("message");
        check_log(59, true);
      end if;
    end loop;
    unmock(default_logger);

    test_runner_cleanup(runner);
  end process;
end architecture;
