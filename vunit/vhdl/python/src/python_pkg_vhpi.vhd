-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.id_pkg.all;
use work.integer_array_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.logger_pkg.all;

package python_ffi_pkg is
  -- The identity of the Python interface, the parent of the session identities
  constant p_python_id : id_t := get_id("vunit_lib:python");

  -- A session is a named Python namespace, created from its name. Only the
  -- default session, the __main__ namespace, is supported by this foreign
  -- language interface.
  type python_session_t is record
    p_data : integer_vector_ptr_t;
  end record;

  impure function new_session(name : string) return python_session_t;
  impure function name(session : python_session_t) return string;

  -- The session the operations are performed in when no other one is given.
  -- It is created the way new_session does, which cannot be called here since
  -- its body is not elaborated until the package body is.
  constant default_session : python_session_t :=
    (p_data => new_integer_vector_ptr(1, value => to_integer(get_id("default", parent => p_python_id))));

  procedure python_setup;
  -- TODO: Looks like Riviera-PRO requires the path to the shared library to be fixed at compile time
  -- and that may become a bit limited. VHDL standard allow for expressions.
  attribute foreign of python_setup : procedure is "VHPI libraries/python python_setup";
  procedure python_cleanup;
  attribute foreign of python_cleanup : procedure is "VHPI libraries/python python_cleanup";

  function p_eval_integer(expr : string) return integer;
  attribute foreign of p_eval_integer : function is "VHPI libraries/python eval_integer";
  impure function eval_integer(expr : string; session : python_session_t := default_session) return integer;
  alias eval is eval_integer[string, python_session_t return integer];

  function p_eval_real(expr : string) return real;
  attribute foreign of p_eval_real : function is "VHPI libraries/python eval_real";
  impure function eval_real(expr : string; session : python_session_t := default_session) return real;
  alias eval is eval_real[string, python_session_t return real];

  function p_eval_integer_vector(expr : string) return integer_vector;
  attribute foreign of p_eval_integer_vector : function is "VHPI libraries/python eval_integer_vector";
  impure function eval_integer_vector(
    expr : string; session : python_session_t := default_session
  ) return integer_vector;
  alias eval is eval_integer_vector[string, python_session_t return integer_vector];

  function p_eval_real_vector(expr : string) return real_vector;
  attribute foreign of p_eval_real_vector : function is "VHPI libraries/python eval_real_vector";
  impure function eval_real_vector(
    expr : string; session : python_session_t := default_session
  ) return real_vector;
  alias eval is eval_real_vector[string, python_session_t return real_vector];

  function p_eval_string(expr : string) return string;
  attribute foreign of p_eval_string : function is "VHPI libraries/python eval_string";
  impure function eval_string(expr : string; session : python_session_t := default_session) return string;
  alias eval is eval_string[string, python_session_t return string];

  procedure p_exec(code : string);
  attribute foreign of p_exec : procedure is "VHPI libraries/python exec";
  procedure exec(code : string; session : python_session_t := default_session);

  -----------------------------------------------------------------------------
  -- Private, the primitives the bridge operations of python_pkg are built on
  -----------------------------------------------------------------------------
  -- Some operations of python_pkg are implemented by the VUnit Python
  -- bridge, which is only available for NVC, GHDL and Questa. The primitives
  -- below are declared so that python_pkg has one body for every simulator,
  -- but they report a failure when they are used.

  -- Logger used to report Python errors
  constant python_logger : logger_t := get_logger(p_python_id);

  -- Result kinds, must match vunit/python_bridge/runtime.py
  constant p_kind_integer : integer := 0;
  constant p_kind_real : integer := 1;
  constant p_kind_boolean : integer := 2;
  constant p_kind_string : integer := 3;
  constant p_kind_std_ulogic : integer := 4;
  constant p_kind_std_ulogic_vector : integer := 5;
  constant p_kind_signed : integer := 6;
  constant p_kind_unsigned : integer := 7;
  constant p_kind_integer_array : integer := 8;
  constant p_kind_integer_vector : integer := 9;
  constant p_kind_real_vector : integer := 10;

  -- Name of the operation, used in the error messages
  impure function p_eval_operation(expr : string; session : python_session_t := default_session) return string;

  -- Execute the Python file with the given name
  impure function p_exec_file(
    file_name : string; session : python_session_t := default_session
  ) return boolean;

  -- Evaluate expr and convert the value to the VHDL type given by kind. width
  -- is the length of a std_ulogic_vector, signed or unsigned result, -1 when
  -- it is not known.
  impure function p_eval(
    expr      : string;
    kind      : integer;
    width     : integer;
    operation : string;
    session   : python_session_t := default_session
  ) return boolean;

  -- The result of the last evaluation
  impure function p_result_integer return integer;
  impure function p_result_string return string;
  impure function p_result_integer_array return integer_array_t;

  -- Transfer an integer_array_t to Python and return the id it is staged
  -- under, -1 on failure.
  impure function p_stage_array(arr : integer_array_t; operation : string) return integer;
end package;

package body python_ffi_pkg is
  impure function new_session(name : string) return python_session_t is
  begin
    return (p_data => new_integer_vector_ptr(1, value => to_integer(get_id(name, parent => p_python_id))));
  end;

  -- The identity of a session, which is what two sessions are compared by
  impure function p_id(session : python_session_t) return id_t is
  begin
    return to_id(get(session.p_data, 0));
  end;

  impure function name(session : python_session_t) return string is
  begin
    return name(p_id(session));
  end;

  impure function p_is_default(session : python_session_t) return boolean is
  begin
    return p_id(session) = p_id(default_session);
  end;

  procedure p_check_session(session : python_session_t) is
  begin
    if not p_is_default(session) then
      report "Python sessions are only supported with NVC, GHDL and Questa" severity failure;
    end if;
  end;

  impure function eval_integer(expr : string; session : python_session_t := default_session) return integer is
  begin
    p_check_session(session);
    return p_eval_integer(expr);
  end;

  impure function eval_real(expr : string; session : python_session_t := default_session) return real is
  begin
    p_check_session(session);
    return p_eval_real(expr);
  end;

  impure function eval_integer_vector(
    expr : string; session : python_session_t := default_session
  ) return integer_vector is
  begin
    p_check_session(session);
    return p_eval_integer_vector(expr);
  end;

  impure function eval_real_vector(
    expr : string; session : python_session_t := default_session
  ) return real_vector is
  begin
    p_check_session(session);
    return p_eval_real_vector(expr);
  end;

  impure function eval_string(expr : string; session : python_session_t := default_session) return string is
  begin
    p_check_session(session);
    return p_eval_string(expr);
  end;

  procedure exec(code : string; session : python_session_t := default_session) is
  begin
    p_check_session(session);
    p_exec(code);
  end;

  -----------------------------------------------------------------------------
  -- Private, the primitives the bridge operations of python_pkg are built on
  -----------------------------------------------------------------------------
  procedure p_unsupported(name : string) is
  begin
    failure(python_logger, name & " requires NVC, GHDL or Questa");
  end;

  impure function p_eval_operation(expr : string; session : python_session_t := default_session) return string is
  begin
    if p_is_default(session) then
      return "eval(""" & expr & """)";
    end if;
    return "eval(""" & expr & """, session => """ & name(session) & """)";
  end;

  impure function p_exec_file(
    file_name : string; session : python_session_t := default_session
  ) return boolean is
  begin
    p_unsupported("exec_file");
    return false;
  end;

  impure function p_eval(
    expr      : string;
    kind      : integer;
    width     : integer;
    operation : string;
    session   : python_session_t := default_session
  ) return boolean is
  begin
    p_unsupported(operation);
    return false;
  end;

  impure function p_result_integer return integer is
  begin
    p_unsupported("p_result_integer");
    return integer'low;
  end;

  impure function p_result_string return string is
  begin
    p_unsupported("p_result_string");
    return "";
  end;

  impure function p_result_integer_array return integer_array_t is
  begin
    p_unsupported("p_result_integer_array");
    return null_integer_array;
  end;

  impure function p_stage_array(arr : integer_array_t; operation : string) return integer is
  begin
    p_unsupported(operation);
    return -1;
  end;
end package body;
