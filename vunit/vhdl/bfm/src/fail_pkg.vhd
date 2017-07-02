-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Add support for emiting failures that can easily be verified

use work.queue_pkg.all;
use work.integer_vector_ptr_pkg.all;

package fail_pkg is
  type fail_log_t is record
    p_disable_failures : integer_vector_ptr_t;
    p_fail_queue : queue_t;
  end record;
  constant null_fail_log : fail_log_t := (p_disable_failures => null_ptr, p_fail_queue => null_queue);

  impure function new_fail_log return fail_log_t;
  procedure fail(fail_log : fail_log_t; msg : string);
  procedure enable_failure(fail_log : fail_log_t);
  procedure disable_failure(fail_log : fail_log_t);
  procedure check_no_failures(fail_log : fail_log_t);
  impure function pop_failure(fail_log : fail_log_t) return string;
end package;

package body fail_pkg is
  impure function new_fail_log return fail_log_t is
    variable fail_log : fail_log_t;
  begin
    fail_log := (p_disable_failures => allocate(1),
                 p_fail_queue => allocate);
    enable_failure(fail_log);
    return fail_log;
  end;

  procedure fail(fail_log : fail_log_t; msg : string) is
  begin
    if get(fail_log.p_disable_failures, 0) = 1 then
      report msg;
      push_string(fail_log.p_fail_queue, msg);
    else
      report msg severity failure;
    end if;
  end;

  procedure enable_failure(fail_log : fail_log_t) is
  begin
    check_no_failures(fail_log);
    set(fail_log.p_disable_failures, 0, 0);
  end;

  procedure disable_failure(fail_log : fail_log_t) is
  begin
    set(fail_log.p_disable_failures, 0, 1);
  end;

  procedure check_no_failures(fail_log : fail_log_t) is
  begin
    while length(fail_log.p_fail_queue) > 0 loop
      report "Got unexpected failure: "  & pop_string(fail_log.p_fail_queue)
        severity failure;
    end loop;
  end;

  impure function pop_failure(fail_log : fail_log_t) return string is
  begin
    return pop_string(fail_log.p_fail_queue);
  end;
end package body;
