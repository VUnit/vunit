# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""Templates for the verification component testbench."""

from string import Template


TB_TEMPLATE_TEMPLATE = Template(
    """\
-- Read the TODOs to complete this template.

${context_items}
entity tb_${vc_name}_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_${vc_name}_compliance is

${constructor}
${signal_declarations}
begin
  -- DO NOT modify the test runner process.
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

${vc_instantiation}
end architecture;
"""
)

ARCHITECTURE_DECLARATIONS_TEMPLATE = Template(
    """\
  constant custom_actor : actor_t := new_actor("vc", inbox_size => 1);
  constant custom_logger : logger_t := get_logger("vc");
  constant custom_checker : checker_t := new_checker(get_logger("vc_check"));

  impure function create_handle return ${vc_handle_t} is
    variable handle : ${vc_handle_t};
    variable logger : logger_t := ${default_logger};
    variable actor : actor_t := ${default_actor};
    variable checker : checker_t := ${default_checker};
  begin
    if use_custom_logger then
      logger := custom_logger;
    end if;

    if use_custom_actor then
      actor := custom_actor;
    end if;

    if use_custom_checker then
      checker := custom_checker;
    end if;

    return ${vc_constructor_name}(
      ${specified_parameters}
      logger => logger,
      actor => actor,
      checker => checker,
      unexpected_msg_type_policy => unexpected_msg_type_policy);
  end;

  constant ${vc_handle_name} : ${vc_handle_t} := create_handle;
  constant unexpected_msg : msg_type_t := new_msg_type("unexpected msg");
"""
)

TEST_RUNNER_TEMPLATE = Template(
    """\
test_runner : process
  variable t_start : time;
  variable msg : msg_t;
  variable error_logger : logger_t;
begin
  test_runner_setup(runner, runner_cfg);

  while test_suite loop

    if run("Test that sync interface is supported") then
      t_start := now;
      wait_for_time(net, as_sync(${vc_handle_name}), 1 ns);
      wait_for_time(net, as_sync(${vc_handle_name}), 2 ns);
      wait_for_time(net, as_sync(${vc_handle_name}), 3 ns);
      check_equal(now - t_start, 0 ns);
      t_start := now;
      wait_until_idle(net, as_sync(${vc_handle_name}));
      check_equal(now - t_start, 6 ns);

    elsif run("Test that the actor can be customised") then
      t_start := now;
      wait_for_time(net, as_sync(${vc_handle_name}), 1 ns);
      wait_for_time(net, as_sync(${vc_handle_name}), 2 ns);
      check_equal(now - t_start, 0 ns);
      wait_for_time(net, as_sync(${vc_handle_name}), 3 ns);
      check_equal(now - t_start, 1 ns);
      wait_until_idle(net, as_sync(${vc_handle_name}));
      check_equal(now - t_start, 6 ns);

    elsif run("Test unexpected message handling") then
      if use_custom_checker then
        error_logger := get_logger(custom_checker);
      else
        error_logger := custom_logger;
      end if;
      mock(error_logger, failure);
      msg := new_msg(unexpected_msg);
      send(net, custom_actor, msg);
      wait for 1 ns;
      if unexpected_msg_type_policy = fail then
        check_only_log(error_logger, "Got unexpected message unexpected msg", failure);
      else
        check_no_log;
      end if;
      unmock(error_logger);
    end if;

  end loop;

  test_runner_cleanup(runner);
end process test_runner;"""
)

GENERICS_TEMPLATE = """use_custom_logger : boolean := false;
    use_custom_checker : boolean := false;
    use_custom_actor : boolean := false;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail;
    runner_cfg : string"""
