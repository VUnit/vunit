library vunit_lib;
context vunit_lib.vunit_context;

entity tb_counting_errors is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_counting_errors is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("Test that fails multiple times but doesn't stop") then
        check_equal(17, 18);
        check_equal(17, 19);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
