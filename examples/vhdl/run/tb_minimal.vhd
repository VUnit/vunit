library vunit_lib;
context vunit_lib.vunit_context;

entity tb_minimal is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_minimal is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    check_equal(to_string(17), "17");
    test_runner_cleanup(runner);
  end process;
end architecture;
