-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- This package contains common functionality for VCs.

context work.vunit_context;
context work.com_context;

package vc_pkg is
  type unexpected_msg_type_policy_t is (fail, ignore);

  type std_cfg_t is record
    p_data : integer_vector_ptr_t;
  end record;

  constant null_std_cfg : std_cfg_t := (
    p_data => null_integer_vector_ptr
  );

  -- Creates a standard VC configuration with an id, an actor, a logger, a
  -- checker, and an unexpected message type policy.
  --
  -- If id = null_id, the id will be assigned the name provider:vc_name:n where n is 1
  -- for the first instance and increasing with one for every additional instance.
  --
  -- The id must not have an associated actor before the call as that may indicate
  -- several users of the same actor.
  --
  -- If a logger exist for the id, it will be reused. If not, a new logger is created.
  -- A new checker is created that reports to the logger.
  impure function create_std_cfg(
    id : id_t := null_id;
    provider : string := "";
    vc_name : string := "";
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return std_cfg_t;

  -- Used to create enumerated ids from a parent id. The first created
  -- id will be <parent name>:1, the second <parent name>:2 and so on
  impure function enumerate(parent : id_t) return id_t;

  -- These functions extracts information from the standard VC configuration
  impure function get_id(std_cfg : std_cfg_t) return id_t;
  impure function get_actor(std_cfg : std_cfg_t) return actor_t;
  impure function get_logger(std_cfg : std_cfg_t) return logger_t;
  impure function get_checker(std_cfg : std_cfg_t) return checker_t;
  impure function unexpected_msg_type_policy(std_cfg : std_cfg_t) return unexpected_msg_type_policy_t;

  -- Handle messages with unexpected message type according to the standard configuration
  procedure unexpected_msg_type(msg_type : msg_type_t; std_cfg : std_cfg_t);

end package;

package body vc_pkg is
  constant vc_pkg_logger  : logger_t  := get_logger("vunit_lib:vc_pkg");
  constant vc_pkg_checker : checker_t := new_checker(vc_pkg_logger);

  constant id_idx : natural := 0;
  constant actor_idx : natural := 1;
  constant logger_idx : natural := 2;
  constant checker_idx : natural := 3;
  constant unexpected_msg_type_policy_idx : natural := 4;
  constant std_cfg_length : natural := unexpected_msg_type_policy_idx + 1;

  impure function enumerate(parent : id_t) return id_t is
  begin
    return get_id(to_string(num_children(parent) + 1), parent => parent);
  end;

  impure function create_std_cfg(
    id : id_t := null_id;
    provider : string := "";
    vc_name : string := "";
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return std_cfg_t is
    variable std_cfg : std_cfg_t;
    variable provider_id : id_t;
    variable vc_id : id_t;
    variable instance_id : id_t;
    variable actor : actor_t;
    variable logger : logger_t;
  begin
    std_cfg.p_data := new_integer_vector_ptr(std_cfg_length);

    if id /= null_id then
      instance_id := id;
    else
      if provider = "" then
        check_failed(vc_pkg_checker, "A provider must be provided.");

        -- Simplifies testing when vc_pkg_checker logger is mocked
        return null_std_cfg;
      end if;

      if vc_name = "" then
        check_failed(vc_pkg_checker, "A VC name must be provided.");

        -- Simplifies testing when vc_pkg_checker logger is mocked
        return null_std_cfg;
      end if;

      provider_id := get_id(provider);
      vc_id := get_id(vc_name, parent => provider_id);
      instance_id := enumerate(vc_id);
    end if;
    set(std_cfg.p_data, id_idx, to_integer(instance_id));

    if find(instance_id, enable_deferred_creation => false) /= null_actor then
      check_failed(vc_pkg_checker, "An actor already exists for " & full_name(instance_id) & ".");

      -- Simplifies testing when vc_pkg_checker logger is mocked
      return null_std_cfg;
    else
      actor := new_actor(instance_id);
    end if;
    set(std_cfg.p_data, actor_idx, to_integer(actor));

    logger := get_logger(instance_id);
    set(std_cfg.p_data, logger_idx, to_integer(logger));

    set(std_cfg.p_data, checker_idx, to_integer(new_checker(logger)));

    set(
      std_cfg.p_data,
      unexpected_msg_type_policy_idx,
      unexpected_msg_type_policy_t'pos(unexpected_msg_type_policy)
    );

    return std_cfg;
  end;

  impure function get_id(std_cfg : std_cfg_t) return id_t is
  begin
    return to_id(get(std_cfg.p_data, id_idx));
  end;

  impure function get_actor(std_cfg : std_cfg_t) return actor_t is
  begin
    return to_actor(get(std_cfg.p_data, actor_idx));
  end;

  impure function get_logger(std_cfg : std_cfg_t) return logger_t is
  begin
    return to_logger(get(std_cfg.p_data, logger_idx));
  end;

  impure function get_checker(std_cfg : std_cfg_t) return checker_t is
  begin
    return to_checker(get(std_cfg.p_data, checker_idx));
  end;

  impure function unexpected_msg_type_policy(std_cfg : std_cfg_t) return unexpected_msg_type_policy_t is
  begin
    return unexpected_msg_type_policy_t'val(get(std_cfg.p_data, unexpected_msg_type_policy_idx));
  end;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                std_cfg : std_cfg_t) is
    constant code : integer := msg_type.p_code;
  begin
    if is_already_handled(msg_type) or unexpected_msg_type_policy(std_cfg) = ignore then
      null;
    elsif is_valid(code) then
      check_failed(
        get_checker(std_cfg),
        "Got unexpected message " & to_string(to_string_ptr(get(p_msg_types.p_name_ptrs, code)))
      );
    else
      check_failed(
        get_checker(std_cfg),
        "Got invalid message with code " & to_string(code)
      );
    end if;
  end procedure;
end package body;
