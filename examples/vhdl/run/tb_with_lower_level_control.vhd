library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_lower_level_control is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_with_lower_level_control is
  signal start_stimuli, stimuli_done : boolean := false;
begin

  test_control: entity work.test_control
    generic map (
      nested_runner_cfg => runner_cfg);

end architecture;
