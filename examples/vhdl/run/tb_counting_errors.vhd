library vunit_lib;
context vunit_lib.vunit_context;

entity tb_other_error_mechanism is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_other_error_mechanism is
begin
  test_runner : process
    variable error_counter : natural := 0;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that fails on other mechanism") then
        error_counter := error_counter + 1;
      end if;
    end loop;

    test_runner_cleanup(runner, error_counter > 0);
  end process;
end architecture;
