-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- The foreign language interface of the Python package for NVC and GHDL,
-- implemented with the VUnit Python bridge (vunit/python_bridge). It provides
-- the same subprograms as the FLI and VHPI variants but over the private
-- python_bridge_pkg, which VUnit generates when Python support is enabled with
-- add_python().
--
-- Deviations from the other variants:
--   * The subprograms are impure since they call impure foreign subprograms.
--   * Errors are reported as failures on python_logger rather than aborting
--     the simulation directly, which makes them observable from VHDL.
--   * Sessions other than the default one are supported.
--
-- The p_ prefixed declarations are the private primitives the bridge
-- operations of python_pkg are built on. They are not part of the API. The FLI and VHPI
-- variants of this package declare the same primitives and implement them by
-- reporting a failure.

use work.id_pkg.all;
use work.integer_array_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.logger_pkg.all;
use work.python_bridge_pkg.all;

package python_ffi_pkg is
  -- The identity of the Python interface. It is the parent of the session
  -- identities and of python_logger.
  constant p_python_id : id_t := get_id("vunit_lib:python");

  -- Logger used to report Python errors, for example exceptions with their
  -- traceback. An operation performed in a session other than the default one
  -- reports on the logger of that session, get_logger(<its name>,
  -- python_logger), which is a child of python_logger.
  constant python_logger : logger_t := get_logger(p_python_id);

  -- A session is a named Python namespace. Sessions are isolated from each
  -- other and are created from their name, which is an identity under the
  -- identity of the Python interface:
  --
  --   constant golden_model : python_session_t := new_session("golden_model");
  --
  -- The Python namespace is created on first use. The default session is the
  -- __main__ namespace.
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

  -- Start the embedded Python interpreter eagerly. Optional and idempotent:
  -- without it the interpreter starts on first use.
  procedure python_setup;

  -- Release the values staged for integer_array_t arguments. Optional: they
  -- are released when the simulator process ends. The interpreter is not
  -- finalized, so later operations keep working.
  procedure python_cleanup;

  -- Execute Python source code in the namespace of a session
  procedure exec(code : string; session : python_session_t := default_session);

  -- Evaluate a Python expression and convert its value to a VHDL type
  impure function eval_integer(expr : string; session : python_session_t := default_session) return integer;
  alias eval is eval_integer[string, python_session_t return integer];

  impure function eval_real(expr : string; session : python_session_t := default_session) return real;
  alias eval is eval_real[string, python_session_t return real];

  impure function eval_integer_vector(
    expr : string; session : python_session_t := default_session
  ) return integer_vector;
  alias eval is eval_integer_vector[string, python_session_t return integer_vector];

  impure function eval_real_vector(
    expr : string; session : python_session_t := default_session
  ) return real_vector;
  alias eval is eval_real_vector[string, python_session_t return real_vector];

  impure function eval_string(expr : string; session : python_session_t := default_session) return string;
  alias eval is eval_string[string, python_session_t return string];

  -----------------------------------------------------------------------------
  -- Private, the primitives the bridge operations of python_pkg are built on
  -----------------------------------------------------------------------------
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

  -- The logger the operations of a session report on
  impure function p_logger(session : python_session_t := default_session) return logger_t;

  -- Names of the operations, used in the error messages
  impure function p_exec_operation(session : python_session_t := default_session) return string;
  impure function p_exec_file_operation(
    file_name : string; session : python_session_t := default_session
  ) return string;
  impure function p_eval_operation(expr : string; session : python_session_t := default_session) return string;

  -- The error of the last failed bridge operation, typically a Python traceback
  impure function p_error_text return string;

  -- Report a failed operation (status /= 0) with its error. True if it succeeded.
  impure function p_succeeded(
    status : integer; operation : string; logger : logger_t := python_logger
  ) return boolean;

  -- Transfer a string to the bridge buffer. Returns the bridge status.
  impure function p_send(text : string) return integer;

  -- Start an operation in a session
  impure function p_begin(session : python_session_t; operation : string) return boolean;

  -- Execute text as Python source code (is_file = 0) or as a Python file name (is_file = 1)
  impure function p_exec(
    text      : string;
    is_file   : integer;
    operation : string;
    session   : python_session_t := default_session
  ) return boolean;

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
  impure function p_result_integer_vector return integer_vector;
  impure function p_result_real_vector return real_vector;
  impure function p_result_integer_array return integer_array_t;

  -- Transfer an integer_array_t to Python and return the id it is staged
  -- under, -1 on failure. Python source code refers to the value as
  -- __vunit__.staged(<id>).
  impure function p_stage_array(arr : integer_array_t; operation : string) return integer;
end package;

package body python_ffi_pkg is
  -----------------------------------------------------------------------------
  -- Sessions
  -----------------------------------------------------------------------------
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

  -- Mocking a logger does not capture the logs of its children, so the
  -- operations of the default session report on python_logger itself rather
  -- than on a logger of their own.
  impure function p_logger(session : python_session_t := default_session) return logger_t is
  begin
    if p_is_default(session) then
      return python_logger;
    end if;
    return get_logger(p_id(session));
  end;

  -----------------------------------------------------------------------------
  -- Operation names
  -----------------------------------------------------------------------------
  impure function p_exec_operation(session : python_session_t := default_session) return string is
  begin
    if p_is_default(session) then
      return "exec";
    end if;
    return "exec(session => """ & name(session) & """)";
  end;

  impure function p_exec_file_operation(
    file_name : string; session : python_session_t := default_session
  ) return string is
  begin
    if p_is_default(session) then
      return "exec_file(""" & file_name & """)";
    end if;
    return "exec_file(""" & file_name & """, session => """ & name(session) & """)";
  end;

  impure function p_eval_operation(expr : string; session : python_session_t := default_session) return string is
  begin
    if p_is_default(session) then
      return "eval(""" & expr & """)";
    end if;
    return "eval(""" & expr & """, session => """ & name(session) & """)";
  end;

  -----------------------------------------------------------------------------
  -- Transfers through the bridge
  -----------------------------------------------------------------------------
  impure function p_error_text return string is
    constant len : natural := vpy_error_length;
    variable result : string(1 to len);
    variable chunk : string_chunk_t;
    variable offset, n : natural := 0;
  begin
    while offset < len loop
      n := minimum(chunk_length, len - offset);
      vpy_error_read(chunk, offset, n);
      result(offset + 1 to offset + n) := chunk(1 to n);
      offset := offset + n;
    end loop;
    return result;
  end;

  impure function p_succeeded(
    status : integer; operation : string; logger : logger_t := python_logger
  ) return boolean is
  begin
    if status = 0 then
      return true;
    end if;
    failure(logger, operation & " failed:" & LF & p_error_text);
    return false;
  end;

  impure function p_send(text : string) return integer is
    alias normalized : string(1 to text'length) is text;
    variable chunk : string_chunk_t;
    variable offset, n : natural := 0;
    variable status : integer;
  begin
    status := vpy_buffer_clear;
    while offset < text'length and status = 0 loop
      n := minimum(chunk_length, text'length - offset);
      chunk(1 to n) := normalized(offset + 1 to offset + n);
      status := vpy_buffer_append(chunk, n);
      offset := offset + n;
    end loop;
    return status;
  end;

  impure function p_begin(session : python_session_t; operation : string) return boolean is
    constant logger : logger_t := p_logger(session);
  begin
    return p_succeeded(p_send(name(session)), operation, logger) and p_succeeded(vpy_begin, operation, logger);
  end;

  impure function p_exec(
    text      : string;
    is_file   : integer;
    operation : string;
    session   : python_session_t := default_session
  ) return boolean is
    constant logger : logger_t := p_logger(session);
  begin
    return p_begin(session, operation)
      and p_succeeded(p_send(text), operation, logger)
      and p_succeeded(vpy_execute(is_file), operation, logger);
  end;

  impure function p_exec_file(
    file_name : string; session : python_session_t := default_session
  ) return boolean is
  begin
    return p_exec(file_name, 1, p_exec_file_operation(file_name, session), session);
  end;

  impure function p_eval(
    expr      : string;
    kind      : integer;
    width     : integer;
    operation : string;
    session   : python_session_t := default_session
  ) return boolean is
    constant logger : logger_t := p_logger(session);
  begin
    return p_begin(session, operation)
      and p_succeeded(p_send(expr), operation, logger)
      and p_succeeded(vpy_eval(kind, width), operation, logger);
  end;

  -----------------------------------------------------------------------------
  -- Results
  -----------------------------------------------------------------------------
  impure function p_result_integer return integer is
  begin
    return vpy_result_integer;
  end;

  impure function p_result_string return string is
    constant len : natural := vpy_result_meta(0);
    variable result : string(1 to len);
    variable chunk : string_chunk_t;
    variable offset, n : natural := 0;
  begin
    while offset < len loop
      n := minimum(chunk_length, len - offset);
      vpy_result_read_string(chunk, offset, n);
      result(offset + 1 to offset + n) := chunk(1 to n);
      offset := offset + n;
    end loop;
    return result;
  end;

  impure function p_result_integer_vector return integer_vector is
    constant len : natural := vpy_result_meta(0);
    variable result : integer_vector(0 to len - 1);
    variable chunk : integer_chunk_t;
    variable offset, n : natural := 0;
  begin
    while offset < len loop
      n := minimum(chunk_length, len - offset);
      vpy_result_read_integers(chunk, offset, n);
      result(offset to offset + n - 1) := chunk(0 to n - 1);
      offset := offset + n;
    end loop;
    return result;
  end;

  impure function p_result_real_vector return real_vector is
    constant len : natural := vpy_result_meta(0);
    variable result : real_vector(0 to len - 1);
    variable chunk : real_chunk_t;
    variable offset, n : natural := 0;
  begin
    while offset < len loop
      n := minimum(chunk_length, len - offset);
      vpy_result_read_reals(chunk, offset, n);
      result(offset to offset + n - 1) := chunk(0 to n - 1);
      offset := offset + n;
    end loop;
    return result;
  end;

  impure function p_result_integer_array return integer_array_t is
    constant len : natural := vpy_result_meta(0);
    variable result : integer_array_t := new_3d(
      width => vpy_result_meta(1),
      height => vpy_result_meta(2),
      depth => vpy_result_meta(3),
      bit_width => vpy_result_meta(4),
      is_signed => vpy_result_meta(5) /= 0
    );
    variable chunk : integer_chunk_t;
    variable offset, n : natural := 0;
  begin
    while offset < len loop
      n := minimum(chunk_length, len - offset);
      vpy_result_read_integers(chunk, offset, n);
      for idx in 0 to n - 1 loop
        set(result, offset + idx, chunk(idx));
      end loop;
      offset := offset + n;
    end loop;
    return result;
  end;

  -----------------------------------------------------------------------------
  -- Values transferred to Python
  -----------------------------------------------------------------------------
  impure function p_stage_array(arr : integer_array_t; operation : string) return integer is
    constant len : natural := length(arr);
    variable chunk : integer_chunk_t;
    variable offset, n : natural := 0;
    variable staged_id : integer;
  begin
    if not p_succeeded(
      vpy_push_array(len, width(arr), height(arr), depth(arr), bit_width(arr), boolean'pos(is_signed(arr))),
      operation
    ) then
      return -1;
    end if;

    while offset < len loop
      n := minimum(chunk_length, len - offset);
      for idx in 0 to n - 1 loop
        chunk(idx) := get(arr, offset + idx);
      end loop;
      if not p_succeeded(vpy_array_write(chunk, n), operation) then
        return -1;
      end if;
      offset := offset + n;
    end loop;

    staged_id := vpy_stage;
    if staged_id < 1 then
      failure(python_logger, operation & " failed:" & LF & p_error_text);
      return -1;
    end if;
    return staged_id;
  end;

  -----------------------------------------------------------------------------
  -- The API
  -----------------------------------------------------------------------------
  procedure python_setup is
    variable ok : boolean;
  begin
    ok := p_succeeded(vpy_setup, "python_setup");
  end;

  procedure python_cleanup is
    variable ok : boolean;
  begin
    ok := p_succeeded(vpy_cleanup, "python_cleanup");
  end;

  procedure exec(code : string; session : python_session_t := default_session) is
    variable ok : boolean;
  begin
    ok := p_exec(code, 0, p_exec_operation(session), session);
  end;

  impure function eval_integer(expr : string; session : python_session_t := default_session) return integer is
  begin
    if p_eval(expr, p_kind_integer, -1, p_eval_operation(expr, session), session) then
      return vpy_result_integer;
    end if;
    return integer'low;
  end;

  impure function eval_real(expr : string; session : python_session_t := default_session) return real is
  begin
    if p_eval(expr, p_kind_real, -1, p_eval_operation(expr, session), session) then
      return vpy_result_real;
    end if;
    return 0.0;
  end;

  impure function eval_integer_vector(
    expr : string; session : python_session_t := default_session
  ) return integer_vector is
    constant no_integers : integer_vector(0 downto 1) := (others => 0);
  begin
    if p_eval(expr, p_kind_integer_vector, -1, p_eval_operation(expr, session), session) then
      return p_result_integer_vector;
    end if;
    return no_integers;
  end;

  impure function eval_real_vector(
    expr : string; session : python_session_t := default_session
  ) return real_vector is
    constant no_reals : real_vector(0 downto 1) := (others => 0.0);
  begin
    if p_eval(expr, p_kind_real_vector, -1, p_eval_operation(expr, session), session) then
      return p_result_real_vector;
    end if;
    return no_reals;
  end;

  impure function eval_string(expr : string; session : python_session_t := default_session) return string is
  begin
    if p_eval(expr, p_kind_string, -1, p_eval_operation(expr, session), session) then
      return p_result_string;
    end if;
    return "";
  end;
end package body;
