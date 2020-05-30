-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com
--
-- This package contains common functionality for VC designers.

context work.vunit_context;
context work.com_context;

package vc_pkg is
  type unexpected_msg_type_policy_t is (fail, ignore);

  type std_cfg_t is record
    p_actor                      : actor_t;
    p_logger                     : logger_t;
    p_checker                    : checker_t;
    p_unexpected_msg_type_policy : unexpected_msg_type_policy_t;
  end record;

  constant null_std_cfg : std_cfg_t := (
    p_actor                      => null_actor,
    p_logger                     => null_logger,
    p_checker                    => null_checker,
    p_unexpected_msg_type_policy => ignore
  );

  -- Creates a standard VC configuration with an actor, a logger, a checker, and the policy for handling unexpected messages
  --
  -- * The actor is the actor provided by the actor parameter unless it's the null_actor. In that case a new actor is created
  -- * The logger is the logger provided by the logger parameter unless it's the null_logger. In that case the default logger is used which must not be the null_logger.
  -- * The checker is the checker provided by the checker parameter unless it's the null_checker. In that case the the default checker is used if the logger is the
  --   default logger. Otherwise a new checker is created based on the provided logger. The default checker must not be the null_checker
  -- * The policy for handling unexpected messages is according to the unexpected_msg_type_policy parameter.
  impure function create_std_cfg(
    default_logger             : logger_t;
    default_checker            : checker_t;
    actor                      : actor_t                      := null_actor;
    logger                     : logger_t                     := null_logger;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return std_cfg_t;

  -- These functions extracts the different parts of a standard VC configuration
  impure function get_actor(std_cfg : std_cfg_t) return actor_t;
  impure function get_logger(std_cfg : std_cfg_t) return logger_t;
  impure function get_checker(std_cfg : std_cfg_t) return checker_t;
  impure function unexpected_msg_type_policy(std_cfg : std_cfg_t) return unexpected_msg_type_policy_t;

  -- Handle messages with unexpected message type according to the standard configuration
  procedure unexpected_msg_type(msg_type : msg_type_t; std_cfg : std_cfg_t);

end package;

package body vc_pkg is
  constant vc_logger  : logger_t  := get_logger("vunit_lib:vc_pkg");
  constant vc_checker : checker_t := new_checker(vc_logger);

  impure function create_std_cfg(
    default_logger             : logger_t;
    default_checker            : checker_t;
    actor                      : actor_t                      := null_actor;
    logger                     : logger_t                     := null_logger;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return std_cfg_t is
    variable result : std_cfg_t;
  begin
    check(vc_checker, default_logger /= null_logger, "A default logger must be provided");
    check(vc_checker, default_checker /= null_checker, "A default checker must be provided");

    result.p_actor                      := actor when actor /= null_actor else new_actor;
    result.p_logger                     := logger when logger /= null_logger else default_logger;
    result.p_unexpected_msg_type_policy := unexpected_msg_type_policy;

    if checker = null_checker then
      if logger = default_logger then
        result.p_checker := default_checker;
      else
        result.p_checker := new_checker(logger);
      end if;
    else
      result.p_checker := checker;
    end if;

    return result;
  end;

  impure function get_actor(std_cfg : std_cfg_t) return actor_t is
  begin
    return std_cfg.p_actor;
  end;

  impure function get_logger(std_cfg : std_cfg_t) return logger_t is
  begin
    return std_cfg.p_logger;
  end;

  impure function get_checker(std_cfg : std_cfg_t) return checker_t is
  begin
    return std_cfg.p_checker;
  end;

  impure function unexpected_msg_type_policy(std_cfg : std_cfg_t) return unexpected_msg_type_policy_t is
  begin
    return std_cfg.p_unexpected_msg_type_policy;
  end;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                std_cfg : std_cfg_t) is
  begin
    if unexpected_msg_type_policy(std_cfg) = fail then
      unexpected_msg_type(msg_type, get_checker(std_cfg));
    end if;
  end;
end package body;
