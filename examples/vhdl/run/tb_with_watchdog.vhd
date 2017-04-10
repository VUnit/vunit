library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_watchdog is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_with_watchdog is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that stalls") then
        wait;
      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);
end architecture;
