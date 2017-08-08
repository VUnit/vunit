-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.core_pkg.all;

package body log_levels_pkg is

  type levels_t is record
    names : integer_vector_ptr_t;
    max_level_length : integer_vector_ptr_t;
  end record;

  impure function create_levels return levels_t is
    variable result : levels_t;
    variable name_ptr : string_ptr_t;

    procedure add_level(log_level : log_level_t) is
      constant name : string := log_level_t'image(log_level);
    begin
      if get(result.max_level_length, 0) < name'length then
        set(result.max_level_length, 0, name'length);
      end if;

      set(result.names, log_level_t'pos(log_level),
          to_integer(allocate(log_level_t'image(log_level))));
    end;
  begin
    result := (names => allocate(log_level_t'pos(log_level_t'high)+1,
                                 value => to_integer(null_string_ptr)),
               max_level_length => allocate(1, value => 0));

    add_level(verbose);
    add_level(debug);
    add_level(info);
    add_level(warning);
    add_level(error);
    add_level(failure);

    return result;
  end;

  constant levels : levels_t := create_levels;

  impure function new_log_level(name : string;
                                log_level : numeric_log_level_t) return log_level_t is
    variable name_ptr : string_ptr_t := to_string_ptr(get(levels.names, log_level));
  begin

    if name_ptr /= null_string_ptr then
      core_failure("Cannot create log level """ & name
                   & """ with level " & integer'image(log_level)
                   & " already used by """ & to_string(name_ptr) & """.");
      return null_log_level;
    end if;

    set(levels.names, log_level, to_integer(allocate(name)));

    if name'length > get(levels.max_level_length, 0) then
      set(levels.max_level_length, 0, name'length);
    end if;

    return log_level_t'val(log_level);
  end;

  impure function is_valid(log_level : log_level_t) return boolean is
    variable name_ptr : string_ptr_t := to_string_ptr(get(levels.names, log_level_t'pos(log_level)));
  begin
    return name_ptr /= null_string_ptr;
  end;

  impure function get_name(log_level : log_level_t) return string is
    variable name_ptr : string_ptr_t := to_string_ptr(get(levels.names, log_level_t'pos(log_level)));
  begin
    if name_ptr = null_string_ptr then
      core_failure("Use of undefined level " & log_level_t'image(log_level) & ".");
      return log_level_t'image(log_level);
    end if;
    return to_string(name_ptr);
  end;

  impure function max_level_length return natural is
  begin
    return get(levels.max_level_length, 0);
  end;
end package body;
