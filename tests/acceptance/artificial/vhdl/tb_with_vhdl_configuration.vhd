-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

use std.textio.all;

entity tb_with_vhdl_configuration is
  generic(runner_cfg : string := null_runner_cfg);
end entity;

architecture tb of tb_with_vhdl_configuration is
  component ent
    port(arch : out string(1 to 5));
  end component;

  signal arch : string(1 to 5);

begin
  test_runner : process
    file result_fptr : text;
    variable result_line : line;
  begin
    test_runner_setup(runner, runner_cfg);

    check_equal(runner_cfg, null_runner_cfg);
    check_true(active_python_runner(runner_cfg));
    check(output_path(runner_cfg) /= "");
    check(enabled_test_cases(runner_cfg) /= "__all__");
    check(tb_path(runner_cfg) /= "");

    file_open(result_fptr, join(output_path(runner_cfg), "result.txt"), write_mode);
    write(result_line, arch);
    writeline(result_fptr, result_line);
    file_close(result_fptr);

    while test_suite loop
      if run("test1") then
        null;
      elsif run("test2") then
        null;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  ent_inst : ent
    port map(
      arch => arch
    );

end architecture;
