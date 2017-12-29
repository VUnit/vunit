-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;

package msg_types_pkg is
  type msg_types_t is record
    p_name_ptrs : integer_vector_ptr_t;
  end record;

  constant p_msg_types : msg_types_t := (
    p_name_ptrs => new_integer_vector_ptr);

  type msg_type_t is record
    p_code : integer;
  end record;

  constant msg_types_logger : logger_t := get_logger("vunit_lib:msg_types_pkg");

  impure function new_msg_type(name : string) return msg_type_t;
  impure function name( msg_type : msg_type_t) return string;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                    logger : logger_t := msg_types_logger);

  procedure push_msg_type(msg : msg_t;
                              msg_type : msg_type_t;
                              logger : logger_t := msg_types_logger);
  alias push is push_msg_type [msg_t, msg_type_t, logger_t];

  impure function pop_msg_type(msg : msg_t;
                                   logger : logger_t := msg_types_logger) return msg_type_t;
  alias pop is pop_msg_type [msg_t, logger_t return msg_type_t];

  procedure handle_message(variable msg_type : inout msg_type_t);
  impure function is_already_handled(msg_type : msg_type_t) return boolean;

end package;

package body msg_types_pkg is
  impure function new_msg_type(name : string) return msg_type_t is
    variable code : integer := length(p_msg_types.p_name_ptrs);
  begin
    resize(p_msg_types.p_name_ptrs, code+1);
    set(p_msg_types.p_name_ptrs, code, to_integer(new_string_ptr(name)));
    return (p_code => code);
  end function;

  impure function name( msg_type : msg_type_t) return string is
  begin
    return to_string(to_string_ptr(get(p_msg_types.p_name_ptrs, msg_type.p_code)));
  end;

  constant message_handled : msg_type_t := new_msg_type("message handled");

  impure function is_valid(code : integer) return boolean is
  begin
    return 0 <= code and code < length(p_msg_types.p_name_ptrs);
  end;

  procedure handle_message(variable msg_type : inout msg_type_t) is
  begin
    msg_type := message_handled;
  end;

  impure function is_already_handled(msg_type : msg_type_t) return boolean is
  begin
    return msg_type = message_handled;
  end;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                    logger : logger_t := msg_types_logger) is
    constant code : integer := msg_type.p_code;
  begin
    if is_already_handled(msg_type) then
      null;
    elsif is_valid(code) then
      failure(logger, "Got unexpected message " & to_string(to_string_ptr(get(p_msg_types.p_name_ptrs, code))));
    else
      failure(logger, "Got invalid message with code " & to_string(code));
    end if;
  end procedure;

  procedure push_msg_type(msg : msg_t;
                              msg_type : msg_type_t;
                              logger : logger_t := msg_types_logger) is
  begin
    push(msg, msg_type.p_code);
  end;

  impure function pop_msg_type(msg : msg_t;
                                   logger : logger_t := msg_types_logger) return msg_type_t is
    constant code : integer := pop(msg);
  begin
    if not is_valid(code) then
      failure(logger, "Got invalid message with code " & to_string(code));
    end if;
    return (p_code => code);
  end;
end package body;
