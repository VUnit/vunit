-- Run base package provides fundamental run functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;
use work.run_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.id_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

package sync_point_pkg is
  constant sync_point_logger : logger_t := get_logger("vunit_lib:sync_point_pkg");
  constant sync_point_checker : checker_t := new_checker(sync_point_logger);

  subtype sync_point_t is std_logic_vector(31 downto 0);
  type sync_point_vec_t is array (integer range <>) of sync_point_t;

  impure function new_sync_point(
    id : id_t := null_id;
    logger : logger_t := null_logger;
    checker : checker_t := null_checker
  ) return sync_point_t;
  impure function valid(signal sync_point : sync_point_t) return boolean;
  impure function get_id(signal sync_point : sync_point_t) return id_t;
  impure function has_members(signal sync_point : sync_point_t) return boolean;
  impure function is_member(signal sync_point : sync_point_t; id : id_t) return boolean;
  procedure join(signal sync_point : inout sync_point_t; id : in id_t);
  procedure join(signal sync_point1, sync_point2 : inout sync_point_t; id : in id_t);
  procedure join(signal sync_point1, sync_point2, sync_point3 : inout sync_point_t; id : in id_t);
  procedure join(signal sync_point1, sync_point2, sync_point3, sync_point4 : inout sync_point_t; id : in id_t);
  procedure join(signal sync_point : inout sync_point_t; id_vec : in id_vec_t);
  procedure leave(signal sync_point : inout sync_point_t; id : in id_t);
  procedure leave(signal sync_point : inout sync_point_t; id_vec : in id_vec_t);
  procedure sync(signal sync_point : sync_point_t);
  procedure sync(signal sync_point : inout sync_point_t; id : id_t);

end package;

package body sync_point_pkg is
  type sync_point_db_t is record
    p_ids : integer_vector_ptr_t;
    p_groups : integer_vector_ptr_t;
    p_loggers : integer_vector_ptr_t;
    p_checkers : integer_vector_ptr_t;
    p_number_of_member_events : integer_vector_ptr_t;
  end record;

  constant sync_point_db : sync_point_db_t := (p_ids => new_integer_vector_ptr,
                                               p_groups => new_integer_vector_ptr,
                                               p_loggers => new_integer_vector_ptr,
                                               p_checkers => new_integer_vector_ptr,
                                               p_number_of_member_events => new_integer_vector_ptr(1)
                                              );

  constant sync_point_event : std_logic := '1';
  constant no_sync_point_event : std_logic := 'Z';

  constant sync_point_id_length : positive := 31;
  subtype sync_point_id_rng is integer range sync_point_id_length - 1 downto 0;
  constant sync_point_event_idx : natural := sync_point_id_length;

  impure function new_sync_point(
    id : id_t := null_id;
    logger : logger_t := null_logger;
    checker : checker_t := null_checker
  ) return sync_point_t is
    constant sync_point_id : integer := length(sync_point_db.p_ids);
    variable logger_to_use : logger_t;
    variable checker_to_use : checker_t;
    variable sync_point : sync_point_t;
  begin
    resize(sync_point_db.p_ids, sync_point_id + 1);
    if id = null_id then
      set(sync_point_db.p_ids, sync_point_id, to_integer(new_id("sync point " & integer'image(sync_point_id))));
    else
      set(sync_point_db.p_ids, sync_point_id, to_integer(id));
    end if;

    resize(sync_point_db.p_groups, sync_point_id + 1);
    set(sync_point_db.p_groups, sync_point_id, to_integer(new_integer_vector_ptr));

    if logger = null_logger then
      logger_to_use := get_logger(work.id_pkg.name(to_id(get(sync_point_db.p_ids, sync_point_id))), sync_point_logger);
    else
      logger_to_use := logger;
    end if;

    resize(sync_point_db.p_loggers, sync_point_id + 1);
    set(sync_point_db.p_loggers, sync_point_id, to_integer(logger_to_use));

    if checker = null_checker then
      checker_to_use := new_checker(logger_to_use);
    else
      checker_to_use := checker;
    end if;
    resize(sync_point_db.p_checkers, sync_point_id + 1);
    set(sync_point_db.p_checkers, sync_point_id, to_integer(checker_to_use));

    sync_point(sync_point_event_idx) := no_sync_point_event;
    sync_point(sync_point_id_rng) := std_logic_vector(to_unsigned(sync_point_id, sync_point_id_length));

    return sync_point;
  end;

  impure function valid(signal sync_point : sync_point_t) return boolean is
  begin
    if is_x(sync_point(sync_point_id_rng)) then
      return false;
    else
      return to_integer(unsigned(sync_point(sync_point_id_rng))) < length(sync_point_db.p_ids);
    end if;
  end;

  procedure check(checker : checker_t; signal sync_point : sync_point_t; subprogram : string) is
  begin
    check(checker, valid(sync_point), "Invalid sync point in call to " & subprogram & ".");
  end;

  procedure check(signal sync_point : sync_point_t; subprogram : string) is
  begin
    check(sync_point_checker, sync_point, subprogram);
  end;

  impure function code(signal sync_point : sync_point_t) return integer is
  begin
    return to_integer(unsigned(sync_point(sync_point_id_rng)));
  end;

  impure function get_id(signal sync_point : sync_point_t) return id_t is
  begin
    check(sync_point, "get_id");

    return to_id(get(sync_point_db.p_ids, code(sync_point)));
  end;

  procedure notify_sync_point_update(signal sync_point : inout sync_point_t) is
  begin
    sync_point(sync_point_event_idx) <= sync_point_event;
    if sync_point(sync_point_event_idx) /= sync_point_event then
      wait until sync_point(sync_point_event_idx) = sync_point_event;
    end if;
    sync_point(sync_point_event_idx) <= no_sync_point_event;
  end;

  impure function has_members(signal sync_point : sync_point_t) return boolean is
    constant groups : integer_vector_ptr_t := sync_point_db.p_groups;
  begin
    check(sync_point, "has_members");

    return length(to_integer_vector_ptr(get(groups, code(sync_point)))) > 0;
  end;

  impure function get_logger(signal sync_point : sync_point_t) return logger_t is
  begin
    return to_logger(get(sync_point_db.p_loggers, code(sync_point)));
  end;

  impure function get_checker(signal sync_point : sync_point_t) return checker_t is
  begin
    return to_checker(get(sync_point_db.p_checkers, code(sync_point)));
  end;

  impure function is_member(signal sync_point : sync_point_t; id : id_t) return boolean is
    constant groups : integer_vector_ptr_t := sync_point_db.p_groups;
    constant members : integer_vector_ptr_t := to_integer_vector_ptr(get(groups, code(sync_point)));
  begin
    check(sync_point, "is_member");
    check(get_checker(sync_point), id, "is_member");

    for i in 0 to length(members) - 1 loop
      if get(members, i) = to_integer(id) then
        return true;
      end if;
    end loop;

    return false;
  end;

  procedure add_member_event is
    constant max_number_of_member_events_in_a_delta_cycle : positive := 1000;
  begin
    set(sync_point_db.p_number_of_member_events, 0, (get(sync_point_db.p_number_of_member_events, 0) + 1) mod
      max_number_of_member_events_in_a_delta_cycle
    );
  end;

  procedure join(signal sync_point : inout sync_point_t; id : in id_t) is
    constant groups : integer_vector_ptr_t := sync_point_db.p_groups;
    variable logger : logger_t;
    variable checker : checker_t;
    variable members : integer_vector_ptr_t;
    variable index : natural;
  begin
    check(sync_point, "join");

    logger := get_logger(sync_point);
    checker := get_checker(sync_point);
    members := to_integer_vector_ptr(get(groups, code(sync_point)));

    check(checker, id, "join");

    if is_member(sync_point, id) then
      check_failed(checker, "Cannot use " & name(id) & " to join " & name(get_id(sync_point)) & " again.");
    else
      add_member_event;

      index := 0;
      for i in 0 to length(members) - 1 loop
        exit when get(members, i) = to_integer(null_integer_vector_ptr);
        index := index + 1;
      end loop;

      if index = length(members) then
        resize(members, length(members) + 1);
      end if;

      set(members, index, to_integer(id));

      info(logger, "Joining " & name(get_id(sync_point)) & " with " & name(id) & ".");
    end if;

    notify_sync_point_update(sync_point);
  end;

  procedure join(signal sync_point : inout sync_point_t; id_vec : in id_vec_t) is
  begin
    for i in id_vec'range loop
      join(sync_point, id_vec(i));
    end loop;
  end;

  procedure join(signal sync_point1, sync_point2 : inout sync_point_t; id : in id_t) is
  begin
    join(sync_point1, id);
    join(sync_point2, id);
  end;

  procedure join(signal sync_point1, sync_point2, sync_point3 : inout sync_point_t; id : in id_t) is
  begin
    join(sync_point1, id);
    join(sync_point2, id);
    join(sync_point3, id);
  end;

  procedure join(signal sync_point1, sync_point2, sync_point3, sync_point4 : inout sync_point_t; id : in id_t) is
  begin
    join(sync_point1, id);
    join(sync_point2, id);
    join(sync_point3, id);
    join(sync_point4, id);
  end;

  procedure leave(signal sync_point : inout sync_point_t; id : in id_t) is
    constant groups : integer_vector_ptr_t := sync_point_db.p_groups;
    variable members : integer_vector_ptr_t;
    variable logger : logger_t;
    variable checker : checker_t;
    variable index : integer;
  begin
    check(sync_point, "leave");

    logger := get_logger(sync_point);
    checker := get_checker(sync_point);
    members := to_integer_vector_ptr(get(groups, code(sync_point)));

    check(checker, id, "leave");

    if not is_member(sync_point, id) then
      check_failed(checker, "Cannot use " & name(id) & " to leave " & name(get_id(sync_point)) &
        " without joining it first.");
    else
      add_member_event;

      for i in 0 to length(members) - 1 loop
        if get(members, i) = to_integer(id) then
          set(members, i, to_integer(null_integer_vector_ptr));
        end if;
      end loop;

      index := 0;
      for i in 0 to length(members) - 1 loop
        exit when get(members, i) /= to_integer(null_integer_vector_ptr);
        index := index + 1;
      end loop;

      if index = length(members) then
        reallocate(members, 0);
      end if;

      info(logger, "Leaving " & name(get_id(sync_point)) & " with " & name(id) & ".");
    end if;

    notify_sync_point_update(sync_point);
  end;

  procedure leave(signal sync_point : inout sync_point_t; id_vec : in id_vec_t) is
  begin
    for i in id_vec'range loop
      leave(sync_point, id_vec(i));
    end loop;
  end;

  procedure sync(signal sync_point : sync_point_t) is
    variable logger : logger_t;
    variable number_of_member_events : natural := get(sync_point_db.p_number_of_member_events, 0);

    procedure show_timeout_debug_message is
      constant debug_is_visible : boolean := is_visible(logger, display_handler, debug);
      constant groups : integer_vector_ptr_t := sync_point_db.p_groups;
      variable members : integer_vector_ptr_t;
      variable member_list : line;
      variable n_members : natural := 0;
    begin
      if not debug_is_visible then
        show(logger, display_handler, debug);
      end if;

      for i in 0 to length(groups) - 1 loop
        members := to_integer_vector_ptr(get(groups, i));
        for j in 0 to length(members) - 1 loop
          if n_members /= 0 then
            write(member_list, string'(", "));
          end if;
          write(member_list, name(to_id(get(members, j))));
          n_members := n_members + 1;
        end loop;
      end loop;

      debug(logger, "Test runner timeout while " & name(get_id(sync_point)) & " was waiting for " &
        member_list.all & "."
      );

      if not debug_is_visible then
        hide(logger, display_handler, debug);
      end if;
    end;
  begin
    check(sync_point, "sync");
    logger := get_logger(sync_point);

    avoid_race_condition_with_joining_and_leaving_members : loop
      wait for 0 ns;
      exit when number_of_member_events = get(sync_point_db.p_number_of_member_events, 0);
      number_of_member_events := get(sync_point_db.p_number_of_member_events, 0);
    end loop;

    if has_members(sync_point) then
      loop
        wait until timeout_notification(runner) or not has_members(sync_point);
        exit when not has_members(sync_point);
        show_timeout_debug_message;
      end loop;
    end if;
  end;

  procedure sync(signal sync_point : inout sync_point_t; id : id_t) is
  begin
    leave(sync_point, id);
    sync(sync_point);
  end;

end package body;
