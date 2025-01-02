-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_running_test_case is
  generic(runner_cfg : string);
end entity;

-- start_snippet tb_running_test_case
architecture tb of tb_running_test_case is
  signal start_stimuli : event_t := new_event;
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test scenario A") or run("Test scenario B") then
        notify(start_stimuli);
      elsif run("Test something else") then
        info("Testing something else");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  stimuli_generator: process is
    constant key : key_t := get_entry_key(test_runner_cleanup);
  begin
    wait until is_active(start_stimuli);
    lock(runner, key);

    if running_test_case = "Test scenario A" then
      info("Applying stimuli for scenario A");
    elsif running_test_case = "Test scenario B" then
      info("Applying stimuli for scenario B");
    end if;

    unlock(runner, key);
  end process;

end architecture;
-- end_snippet tb_running_test_case
