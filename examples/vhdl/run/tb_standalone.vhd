library vunit_lib;
context vunit_lib.vunit_context;

entity tb_standalone is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_standalone is
begin
  test_runner : process
    variable filter : log_filter_t;
  begin
    test_runner_setup(runner, runner_cfg);
    logger_init(runner_trace_logger);
    pass_level(runner_trace_logger, info, display_handler, filter);

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
