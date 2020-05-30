# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""Templates for the verification component interface testbench"""

from string import Template

TB_TEMPLATE_TEMPLATE = Template(
    """\
-- Read the TODOs to complete this template.

${context_items}
entity tb_${vc_handle_t}_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_${vc_handle_t}_compliance is
begin
  test_runner : process
    -- TODO: Specify a value for all listed constants.
${constant_declarations}
    -- DO NOT modify this line and the lines below.
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""
)

TB_EPILOGUE_TEMPLATE = Template(
    """
    constant actor1 : actor_t := new_actor("actor1");
    constant logger1 : logger_t := get_logger("logger1");
    constant checker_logger1 : logger_t := get_logger("checker1");
    constant checker1 : checker_t := new_checker(checker_logger1);

    constant actor2 : actor_t := new_actor("actor2");
    constant logger2 : logger_t := get_logger("logger2");
    constant checker_logger2 : logger_t := get_logger("checker2");
    constant checker2 : checker_t := new_checker(checker_logger2);

    constant actor3 : actor_t := new_actor("actor3");
    constant logger3 : logger_t := get_logger("logger3");
    constant checker_logger3 : logger_t := get_logger("checker3");
    constant checker3 : checker_t := new_checker(checker_logger3);

    variable handle1, handle2, handle3 : ${vc_handle_t};
    variable std_cfg1, std_cfg2, std_cfg3 : std_cfg_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test standard configuration") then
${handle1}
        std_cfg1 := get_std_cfg(handle1);

        check(get_actor(std_cfg1) = actor1, "Failed to configure actor with ${vc_constructor_name}");
        check(get_logger(std_cfg1) = logger1, "Failed to configure logger with ${vc_constructor_name}");
        check(get_checker(std_cfg1) = checker1, "Failed to configure checker with ${vc_constructor_name}");
        check(unexpected_msg_type_policy(std_cfg1) = fail,
        "Failed to configure unexpected_msg_type_policy = fail with ${vc_constructor_name}");

${handle2}
        std_cfg2 := get_std_cfg(handle2);

        check(unexpected_msg_type_policy(std_cfg2) = ignore,
        "Failed to configure unexpected_msg_type_policy = ignore with ${vc_constructor_name}");

      elsif run("Test handle independence") then
${handle1}
${handle3}

        std_cfg1 := get_std_cfg(handle1);
        std_cfg2 := get_std_cfg(handle2);
        check(get_actor(std_cfg1) /= get_actor(std_cfg2),
        "Actor shared between handles created by ${vc_constructor_name}");
        check(get_logger(std_cfg1) /= get_logger(std_cfg2),
        "Logger shared between handles created by ${vc_constructor_name}");
        check(get_checker(std_cfg1) /= get_checker(std_cfg2),
        "Checker shared between handles created by ${vc_constructor_name}");
        check(unexpected_msg_type_policy(std_cfg1) /= unexpected_msg_type_policy(std_cfg2),
        "unexpected_msg_type_policy shared between handles created by ${vc_constructor_name}");

      elsif run("Test default logger") then
${handle4}
        std_cfg1 := get_std_cfg(handle1);
        check(get_logger(std_cfg1) /= null_logger,
          "No valid default logger (null_logger) created by ${vc_constructor_name}");
        check(get_logger(std_cfg1) /= default_logger,
          "No valid default logger (default_logger) created by ${vc_constructor_name}");

${handle5}
        std_cfg2 := get_std_cfg(handle2);
        check(get_logger(std_cfg2) /= null_logger,
          "No valid default logger (null_logger) created by ${vc_constructor_name}");
        check(get_logger(std_cfg2) /= default_logger,
          "No valid default logger (default_logger) created by ${vc_constructor_name}");

      elsif run("Test default checker") then
${handle6}
        std_cfg1 := get_std_cfg(handle1);
        check(get_checker(std_cfg1) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg1) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");

${handle7}
        std_cfg2 := get_std_cfg(handle2);
        check(get_checker(std_cfg2) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg2) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");

${handle8}
        std_cfg3 := get_std_cfg(handle3);
        check(get_checker(std_cfg3) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg3) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");
        check(get_logger(get_checker(std_cfg3)) = logger3,
          "Default checker not based on logger provided to ${vc_constructor_name}");

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""
)
