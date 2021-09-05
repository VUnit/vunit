# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

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

    constant actor4 : actor_t := new_actor("actor4");
    constant logger4 : logger_t := get_logger("logger4");
    constant checker_logger4 : logger_t := get_logger("checker4");
    constant checker4 : checker_t := new_checker(checker_logger4);

    constant actor5 : actor_t := new_actor("actor5");
    constant logger5 : logger_t := get_logger("logger5");
    constant checker_logger5 : logger_t := get_logger("checker5");
    constant checker5 : checker_t := new_checker(checker_logger5);

    constant actor6 : actor_t := new_actor("actor6");
    constant logger6 : logger_t := get_logger("logger6");
    constant checker_logger6 : logger_t := get_logger("checker6");
    constant checker6 : checker_t := new_checker(checker_logger6);

    constant actor7 : actor_t := new_actor("actor7");
    constant logger7 : logger_t := get_logger("logger7");
    constant checker_logger7 : logger_t := get_logger("checker7");
    constant checker7 : checker_t := new_checker(checker_logger7);

${handle1}
${handle2}
${handle3}
${handle4}
${handle5}
${handle6}
${handle7}

    variable std_cfg1, std_cfg2, std_cfg3, std_cfg4 : std_cfg_t;
    variable std_cfg5, std_cfg6, std_cfg7 : std_cfg_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test standard configuration") then
        std_cfg1 := get_std_cfg(handle1);

        check(get_actor(std_cfg1) = actor1, "Failed to configure actor with ${vc_constructor_name}");
        check(get_logger(std_cfg1) = logger1, "Failed to configure logger with ${vc_constructor_name}");
        check(get_checker(std_cfg1) = checker1, "Failed to configure checker with ${vc_constructor_name}");
        check(unexpected_msg_type_policy(std_cfg1) = fail,
        "Failed to configure unexpected_msg_type_policy = fail with ${vc_constructor_name}");

        std_cfg2 := get_std_cfg(handle2);

        check(unexpected_msg_type_policy(std_cfg2) = ignore,
        "Failed to configure unexpected_msg_type_policy = ignore with ${vc_constructor_name}");

      elsif run("Test handle independence") then
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
        std_cfg3 := get_std_cfg(handle3);
        check(get_logger(std_cfg3) /= null_logger,
          "No valid default logger (null_logger) created by ${vc_constructor_name}");
        check(get_logger(std_cfg3) /= default_logger,
          "No valid default logger (default_logger) created by ${vc_constructor_name}");

        std_cfg4 := get_std_cfg(handle4);
        check(get_logger(std_cfg4) /= null_logger,
          "No valid default logger (null_logger) created by ${vc_constructor_name}");
        check(get_logger(std_cfg4) /= default_logger,
          "No valid default logger (default_logger) created by ${vc_constructor_name}");

      elsif run("Test default checker") then
        std_cfg5 := get_std_cfg(handle5);
        check(get_checker(std_cfg5) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg5) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");

        std_cfg6 := get_std_cfg(handle6);
        check(get_checker(std_cfg6) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg6) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");

        std_cfg7 := get_std_cfg(handle7);
        check(get_checker(std_cfg7) /= null_checker,
          "No valid default checker (null_checker) created by ${vc_constructor_name}");
        check(get_checker(std_cfg7) /= default_checker,
          "No valid default checker (default_checker) created by ${vc_constructor_name}");
        check(get_logger(get_checker(std_cfg7)) = logger6,
          "Default checker not based on logger provided to ${vc_constructor_name}");

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process test_runner;
end architecture;
"""
)
