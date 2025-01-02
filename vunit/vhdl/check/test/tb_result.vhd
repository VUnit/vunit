-- This test suite verifies basic check functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.string_ops.all;
use vunit_lib.check_pkg.all;
use vunit_lib.checker_pkg.all;
use work.test_support.all;

entity tb_result is
  generic (
    runner_cfg : string := "");
end entity;

architecture test_fixture of tb_result is
begin
  test_runner : process
    constant punctuation_marks_not_preceeded_by_space : string := ".,:;?!";
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that result returns result tag by default") then
        assert_true(result = check_result_tag);

      elsif run("Test that result returns result tag on empty message") then
        assert_true(result("") = check_result_tag);

      elsif run("Test that result returns result tag + message if the message starts with a punctuation mark") then
        for i in punctuation_marks_not_preceeded_by_space'range loop
          assert_true(result(punctuation_marks_not_preceeded_by_space(i) & "Foo") =
                          check_result_tag & punctuation_marks_not_preceeded_by_space(i) & "Foo");
        end loop;

      elsif run("Test that result returns result tag + space + message if the message doesn't start with a punctuation mark") then
        for c in character'left to character'right loop
          if find(punctuation_marks_not_preceeded_by_space, c) = 0 then
            assert_true(result(c & "Foo") =
                            check_result_tag & " " & c & "Foo");
          end if;
        end loop;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end;
