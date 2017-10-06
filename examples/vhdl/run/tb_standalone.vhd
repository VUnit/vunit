library vunit_lib;
context vunit_lib.vunit_context;

entity tb_standalone is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_standalone is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    set_log_level(display_handler, info);

    while test_suite loop
      if run("Test that fails on VUnit check procedure") then
        check_equal(17, 18);
      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");
      end if;
    end loop;

    info("===Summary===" & LF & to_string(get_checker_stat));

    test_runner_cleanup(runner);
  end process;
end architecture;
