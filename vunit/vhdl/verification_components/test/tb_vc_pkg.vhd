-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;
use work.vc_pkg.all;

entity tb_vc_pkg is
  generic(runner_cfg : string);
end entity;

architecture a of tb_vc_pkg is
begin

  main : process
    variable std_cfg : std_cfg_t;
    variable id : id_t;
    variable actor : actor_t;

    constant vc_pkg_logger : logger_t := get_logger("vunit_lib:vc_pkg");
    constant unknown_msg_type : msg_type_t := new_msg_type("unknown_msg");
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that provider must be supplied with null_id") then
        mock(vc_pkg_logger, error);
        std_cfg := create_std_cfg(vc_name => "my_vc");
        check_only_log(vc_pkg_logger, "A provider must be provided.", error);
        unmock(vc_pkg_logger);

      elsif run("Test that vc_name must be supplied with null_id") then
        mock(vc_pkg_logger, error);
        std_cfg := create_std_cfg(provider => "provider");
        check_only_log(vc_pkg_logger, "A VC name must be provided.", error);
        unmock(vc_pkg_logger);

      elsif run("Test standard config with specified id") then
        id := get_id("id");
        std_cfg := create_std_cfg(id => id);
        check(get_id(std_cfg) = id);
        check(get_actor(std_cfg) = find(id, enable_deferred_creation => false));
        check(get_logger(std_cfg) = get_logger(id));
        check(get_logger(get_checker(std_cfg)) = get_logger(id));
        check(unexpected_msg_type_policy(std_cfg) = fail);

      elsif run("Test standard config with null_id") then
        for instance in 1 to 3 loop
          std_cfg := create_std_cfg(provider => "provider", vc_name => "vc_name");
          id := get_id(std_cfg);
          check(id = get_id("provider:vc_name:" & to_string(instance)));
          check(get_actor(std_cfg) = find(id, enable_deferred_creation => false));
          check(get_logger(std_cfg) = get_logger(id));
          check(get_logger(get_checker(std_cfg)) = get_logger(id));
          check(unexpected_msg_type_policy(std_cfg) = fail);
        end loop;

      elsif run("Test standard config with specified unexpected message type policy") then
        std_cfg := create_std_cfg(
          provider => "provider",
          vc_name => "vc_name",
          unexpected_msg_type_policy => ignore
          );
        id := get_id(std_cfg);
        check(id = get_id("provider:vc_name:1"));
        check(get_actor(std_cfg) = find(id, enable_deferred_creation => false));
        check(get_logger(std_cfg) = get_logger(id));
        check(get_logger(get_checker(std_cfg)) = get_logger(id));
        check(unexpected_msg_type_policy(std_cfg) = ignore);

      elsif run("Test failing on reused actor") then
        mock(vc_pkg_logger, error);
        id := get_id("foo:bar");
        actor := new_actor(id);
        std_cfg := create_std_cfg(id => id);
        check_only_log(vc_pkg_logger, "An actor already exists for foo:bar.", error);
        unmock(vc_pkg_logger);

      elsif run("Test failing on unexpected message") then
        id := get_id("id");
        std_cfg := create_std_cfg(id => id);
        mock(get_logger(id), error);
        unexpected_msg_type(unknown_msg_type, std_cfg);
        check_only_log(get_logger(id), "Got unexpected message unknown_msg", error);
        unmock(get_logger(id));

      elsif run("Test ignoring unexpected message") then
        id := get_id("id");
        std_cfg := create_std_cfg(id => id, unexpected_msg_type_policy => ignore);
        mock(get_logger(id), error);
        unexpected_msg_type(unknown_msg_type, std_cfg);
        check_no_log;
        unmock(get_logger(id));

      end if;
    end loop;
    test_runner_cleanup(runner, fail_on_warning => true);
  end process;
end architecture;
