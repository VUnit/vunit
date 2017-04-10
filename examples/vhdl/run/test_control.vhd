library vunit_lib;
context vunit_lib.vunit_context;

entity test_control is
  generic (
    nested_runner_cfg : string);
end entity test_control;

architecture tb of test_control is
begin
  test_runner : process
  begin
    test_runner_setup(runner, nested_runner_cfg);

    while test_suite loop
      if run("Test something") then
        info("Testing something");
      elsif run("Test something else") then
        info("Testing something else");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture tb;
