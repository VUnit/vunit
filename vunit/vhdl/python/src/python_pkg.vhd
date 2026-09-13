-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

use work.python_ffi_pkg.all;
use work.path.all;
use work.run_pkg.all;
use work.runner_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ops.all;

use std.textio.all;

------------------------------------------------------------------------------
-- This file is generated from tools/python_pkg.vhd.in by
-- vunit/vhdl/python/tools/generate_python_pkg.py. Do not edit.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.integer_array_pkg.all;
use work.logger_pkg.all;
------------------------------------------------------------------------------

package python_pkg is
  procedure import_module_from_file(
    module_path, as_module_name : string; session : python_session_t := default_session
  );
  procedure import_run_script(module_name : string := ""; session : python_session_t := default_session);

  function to_py_list_str(vec : integer_vector) return string;
  impure function to_py_list_str(vec : integer_vector_ptr_t) return string;
  function to_py_list_str(vec : real_vector) return string;

  function "+"(l, r : string) return string;

  impure function eval_integer_vector_ptr(
    expr : string; session : python_session_t := default_session
  ) return integer_vector_ptr_t;
  alias eval is eval_integer_vector_ptr[string, python_session_t return integer_vector_ptr_t];

  function to_call_str(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : string := ""
  ) return string;

  type arg_t is record
    name : string;
    value : string;
  end record;
  constant p_positional_arg : string := ".";
  constant p_ignore_arg : string := "-";
  constant null_arg : arg_t := (name => p_ignore_arg, value => "");

  function arg(value : integer) return arg_t;
  function kwarg(kw : string; value : integer) return arg_t;
  function arg(value : string) return arg_t;
  function kwarg(kw : string; value : string) return arg_t;
  function arg(value : integer_vector) return arg_t;
  function kwarg(kw : string; value : integer_vector) return arg_t;
  function arg(value : real) return arg_t;
  function kwarg(kw : string; value : real) return arg_t;
  function arg(value : boolean) return arg_t;
  function kwarg(kw : string; value : boolean) return arg_t;

  impure function call_integer_w_arg(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer;
  alias call is call_integer_w_arg[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return integer];

  procedure call(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  );

  impure function call_integer_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_vector;
  alias call is call_integer_vector[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t
    return integer_vector];

  impure function call_real(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return real;
  alias call is call_real[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return real];

  -----------------------------------------------------------------------------
  -- More argument values of call
  -----------------------------------------------------------------------------
  -- real_vector and integer_vector_ptr_t values become Python lists, a
  -- std_logic value becomes True or False, and an unsigned or signed value of
  -- any width becomes a Python integer written as a hexadecimal literal, which
  -- is therefore not limited to the range of a VHDL integer.
  --
  -- An aggregate or a literal needs a qualified expression to select the
  -- overload, for example arg(real_vector'(1.0, 2.0)). A std_logic_vector is
  -- passed as a string, arg(to_string(slv)), or as a number,
  -- arg_unsigned(unsigned(slv)). The unsigned and signed values have names of
  -- their own since an overload would make a string literal argument,
  -- arg("Hello"), ambiguous.
  --
  -- H and L are read as 1 and 0. Any other metavalue is an error.
  function arg(value : real_vector) return arg_t;
  function kwarg(kw : string; value : real_vector) return arg_t;
  impure function arg(value : integer_vector_ptr_t) return arg_t;
  impure function kwarg(kw : string; value : integer_vector_ptr_t) return arg_t;
  impure function arg(value : std_logic) return arg_t;
  impure function kwarg(kw : string; value : std_logic) return arg_t;
  impure function arg_unsigned(value : unsigned) return arg_t;
  impure function kwarg_unsigned(kw : string; value : unsigned) return arg_t;
  impure function arg_signed(value : signed) return arg_t;
  impure function kwarg_signed(kw : string; value : signed) return arg_t;

  -----------------------------------------------------------------------------
  -- Keyword argument groups
  -----------------------------------------------------------------------------
  -- Keyword arguments combined with & become a single argument, so that a call
  -- can pass more than 10 keyword arguments and can build its keyword
  -- arguments in steps:
  --
  --   call("f", arg(x), kwarg("a", 1) & kwarg("b", 2));
  --
  -- calls f(x, **dict(a=1, b=2)). null_arg is the identity of the operation
  -- and only keyword arguments, or groups of them, can be combined. Python
  -- keeps its own rules: a repeated keyword and a group followed by a
  -- positional argument are syntax errors.
  impure function "&"(l, r : arg_t) return arg_t;

  -----------------------------------------------------------------------------
  -- Operations implemented by the Python bridge (NVC, GHDL and Questa)
  -----------------------------------------------------------------------------
  -- The operations below are implemented by the VUnit Python bridge and are
  -- therefore only available for NVC, GHDL and Questa; the other simulators
  -- report a failure when they are used. Like the other operations, every one
  -- of them takes the session it is performed in as its last parameter,
  -- defaulting to the default session.

  -----------------------------------------------------------------------------
  -- Argument values of call: integer arrays
  -----------------------------------------------------------------------------
  -- An integer_array_t value is transferred to Python and referred to by the
  -- expression, which means that it can be used in several calls.
  impure function arg(value : integer_array_t) return arg_t;
  impure function kwarg(kw : string; value : integer_array_t) return arg_t;

  -----------------------------------------------------------------------------
  -- Results of eval: boolean, std_logic, vectors and arrays
  -----------------------------------------------------------------------------
  -- std_logic_vector and integer_array_t results are only available under
  -- their explicit names, not as eval overloads, which keeps
  -- check_equal(eval("17"), 17) and length(eval("[1, 2]")) unambiguous.
  -- signed and unsigned results are only available in the procedure form
  -- since a function cannot know the width of the result.
  impure function eval_boolean(
    expr : string; session : python_session_t := default_session
  ) return boolean;
  alias eval is eval_boolean[string, python_session_t return boolean];

  impure function eval_std_logic(
    expr : string; session : python_session_t := default_session
  ) return std_logic;
  alias eval is eval_std_logic[string, python_session_t return std_logic];

  impure function eval_std_logic_vector(
    expr : string; session : python_session_t := default_session
  ) return std_logic_vector;

  impure function eval_integer_array(
    expr : string; session : python_session_t := default_session
  ) return integer_array_t;

  procedure eval_std_logic_vector(
    expr : string; result : out std_logic_vector; session : python_session_t := default_session
  );
  procedure eval_signed(
    expr : string; result : out signed; session : python_session_t := default_session
  );
  procedure eval_unsigned(
    expr : string; result : out unsigned; session : python_session_t := default_session
  );

  -----------------------------------------------------------------------------
  -- Results of call: string, boolean, std_logic, vectors and arrays
  -----------------------------------------------------------------------------
  impure function call_real_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return real_vector;
  alias call is call_real_vector[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return real_vector];

  impure function call_string(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return string;
  alias call is call_string[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return string];

  impure function call_integer_vector_ptr(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_vector_ptr_t;
  alias call is call_integer_vector_ptr[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return integer_vector_ptr_t];

  impure function call_boolean(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return boolean;
  alias call is call_boolean[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return boolean];

  impure function call_std_logic(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return std_logic;
  alias call is call_std_logic[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return std_logic];

  impure function call_std_logic_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return std_logic_vector;

  impure function call_integer_array(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_array_t;
  alias call is call_integer_array[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, python_session_t return integer_array_t];

  procedure call_std_logic_vector(
    identifier : string; result : out std_logic_vector;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  );
  procedure call_signed(
    identifier : string; result : out signed;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  );
  procedure call_unsigned(
    identifier : string; result : out unsigned;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  );

  -----------------------------------------------------------------------------
  -- Execution of Python files
  -----------------------------------------------------------------------------
  -- Execute a Python file. A relative file name is relative to the directory
  -- of the run script. The file is executed with __file__ set and its own
  -- directory on sys.path so that it can import its siblings.
  procedure exec_file(file_name : string; session : python_session_t := default_session);
end package;

package body python_pkg is
  -- @formatter:off
  procedure import_module_from_file(
    module_path, as_module_name : string; session : python_session_t := default_session
  ) is
    constant spec_name : string := "__" & as_module_name & "_spec";
    constant code : string :=
    "from importlib.util import spec_from_file_location, module_from_spec" & LF &
    "from pathlib import Path" & LF &
    "import sys" & LF &
    spec_name & " = spec_from_file_location('" & as_module_name & "', str(Path('" & module_path & "')))" & LF &
    as_module_name & " = module_from_spec(" & spec_name & ")" & LF &
    "sys.modules['" & as_module_name & "'] = " & as_module_name & LF &
     spec_name & ".loader.exec_module(" & as_module_name & ")";
  begin
    exec(code, session);
  end;
  -- @formatter:on

  -- Importing a run script runs its module level code, so one without an
  -- if __name__ == "__main__" guard would start VUnit again
  procedure p_check_run_script_guard(script_path : string; session : python_session_t) is
  begin
    exec(
      "from pathlib import Path" & LF &
      "if '__main__' not in Path('" & script_path & "').read_text():" & LF &
      "    raise RuntimeError('The run script " & script_path & " has no if __name__ == ""__main__"" guard, " &
      "importing it would run VUnit again')",
      session);
  end;

  procedure import_run_script(module_name : string := ""; session : python_session_t := default_session) is
    constant script_path : string := run_script_path(get_cfg(runner_state));
    variable path_items : lines_t;
    variable script_name : line;
  begin
    p_check_run_script_guard(script_path, session);
    if module_name = "" then
      -- Extract the last item in the full path
      path_items := split(script_path, "/");
      for idx in path_items'range loop
        if idx = path_items'right then
          script_name := path_items(idx);
        else
          deallocate(path_items(idx));
        end if;
      end loop;
      deallocate(path_items);

      -- Set module name to script name minus its extension
      path_items := split(script_name.all, ".");
      deallocate(script_name);
      for idx in path_items'range loop
        if idx = path_items'left then
          import_module_from_file(script_path, path_items(idx).all, session);
        end if;
        deallocate(path_items(idx));
      end loop;
      deallocate(path_items);
    else
      import_module_from_file(script_path, module_name, session);
    end if;
  end;

  function to_py_list_str(vec : integer_vector) return string is
    variable l : line;
  begin
    swrite(l, "[");
    for idx in vec'range loop
      swrite(l, to_string(vec(idx)));
      if idx /= vec'right then
        swrite(l, ",");
      end if;
    end loop;
    swrite(l, "]");

    return l.all;
  end;

  impure function to_py_list_str(vec : integer_vector_ptr_t) return string is
    variable l : line;
  begin
    swrite(l, "[");
    for idx in 0 to length(vec) - 1 loop
      swrite(l, to_string(get(vec, idx)));
      if idx /= length(vec) - 1 then
        swrite(l, ",");
      end if;
    end loop;
    swrite(l, "]");

    return l.all;
  end;

  function to_py_list_str(vec : real_vector) return string is
    variable l : line;
  begin
    swrite(l, "[");
    for idx in vec'range loop
      -- Use %.16e to ensure that the string representation of the real number is precise enough to avoid loss of
      -- information when double-precision is used.
      swrite(l, to_string(vec(idx), "%.16e"));
      if idx /= vec'right then
        swrite(l, ",");
      end if;
    end loop;
    swrite(l, "]");

    return l.all;
  end;

  function "+"(l, r : string) return string is
  begin
    return l & LF & r;
  end;

  impure function eval_integer_vector_ptr(
    expr : string; session : python_session_t := default_session
  ) return integer_vector_ptr_t is
    constant result_integer_vector : integer_vector := eval(expr, session);
    constant len : natural := result_integer_vector'length;
    constant result_integer_vector_normalized : integer_vector(0 to len - 1) := result_integer_vector;
    constant result : integer_vector_ptr_t := new_integer_vector_ptr(len);
  begin
    for idx in 0 to len - 1 loop
      set(result, idx, result_integer_vector_normalized(idx));
    end loop;

    return result;
  end;

  function to_call_str(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : string := ""
  ) return string is
    -- The non-empty arguments, separated by ", "
    function append(args, arg : string) return string is
    begin
      if arg = "" then
        return args;
      elsif args = "" then
        return arg;
      else
        return args & ", " & arg;
      end if;
    end;
  begin
    return identifier & "(" & append(append(append(append(append(append(append(append(append(append(
      "", arg1), arg2), arg3), arg4), arg5), arg6), arg7), arg8), arg9), arg10) & ")";
  end;

  procedure call(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : string := ""
  ) is
  begin
    exec(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10));
  end;

  function arg(value : integer) return arg_t is
  begin
    return (p_positional_arg, to_string(value));
  end;

  function kwarg(kw : string; value : integer) return arg_t is
  begin
    return (kw, to_string(value));
  end;

  function arg(value : string) return arg_t is
  begin
    return (p_positional_arg, '"' & value & '"');
  end;

  function kwarg(kw : string; value : string) return arg_t is
  begin
    return (kw, '"' & value & '"');
  end;

  function arg(value : integer_vector) return arg_t is
  begin
    return (p_positional_arg, to_py_list_str(value));
  end;

  function kwarg(kw : string; value : integer_vector) return arg_t is
  begin
    return (kw, to_py_list_str(value));
  end;

  function arg(value : real) return arg_t is
  begin
    return (p_positional_arg, to_string(value, "%.16e"));
  end;

  function kwarg(kw : string; value : real) return arg_t is
  begin
    return (kw, to_string(value, "%.16e"));
  end;

  function arg(value : boolean) return arg_t is
  begin
    if value then
      return (p_positional_arg, "True");
    else
      return (p_positional_arg, "False");
    end if;
  end;

  function kwarg(kw : string; value : boolean) return arg_t is
  begin
    if value then
      return (kw, "True");
    else
      return (kw, "False");
    end if;
  end;

  impure function to_call_str(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t
  ) return string is

    function arg_to_str(value : arg_t) return string is
    begin
      if value.name = p_ignore_arg then
        return "";
      elsif value.name = p_positional_arg then
        return value.value;
      else
        return value.name & "=" & value.value;
      end if;
    end;

    constant args : string := "('" & arg_to_str(arg1) & "','" & arg_to_str(arg2) & "','" & arg_to_str(arg3) & "','" & arg_to_str(arg4) & "','" & arg_to_str(arg5) & "','" & arg_to_str(arg6) & "','" & arg_to_str(arg7) & "','" & arg_to_str(arg8) & "','" & arg_to_str(arg9) & "','" & arg_to_str(arg10) & "')";
  begin
    return eval_string("'" & identifier & "(' + ', '.join((arg for arg in " & args & " if arg)) + ')'");
  end;

  impure function call_integer_w_arg(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session);
  end;

  procedure call(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) is
  begin
    exec(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session);
  end;

  impure function call_integer_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_vector is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session);
  end;

  impure function call_real(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return real is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session);
  end;

  -----------------------------------------------------------------------------
  -- More argument values of call
  -----------------------------------------------------------------------------
  -- The Python source text of an argument value. The operation is only used to
  -- report a value that cannot be converted, which gives an empty string.
  function p_arg_value(value : real_vector; operation : string) return string is
  begin
    return to_py_list_str(value);
  end;

  impure function p_arg_value(value : integer_vector_ptr_t; operation : string) return string is
  begin
    return to_py_list_str(value);
  end;

  impure function p_arg_value(value : std_logic; operation : string) return string is
  begin
    if to_x01(value) = '1' then
      return "True";
    elsif to_x01(value) = '0' then
      return "False";
    end if;
    failure(
      python_logger,
      operation & " cannot convert " & std_logic'image(value) & "; expected '0', '1', 'L' or 'H'"
    );
    return "";
  end;

  -- True when the vector has an element other than 0, 1, L and H
  function p_has_metavalue(value : std_logic_vector) return boolean is
  begin
    for idx in value'range loop
      if to_x01(value(idx)) = 'X' then
        return true;
      end if;
    end loop;
    return false;
  end;

  -- The Python hexadecimal literal of the magnitude given by the bits, for
  -- example 0x1F or -0x80. A null range gives 0x0.
  function p_to_hex_literal(bits : std_logic_vector; negative : boolean) return string is
    constant hex_digits : string(1 to 16) := "0123456789ABCDEF";
    constant padding : natural := (4 - bits'length mod 4) mod 4;
    variable padded : std_logic_vector(bits'length + padding - 1 downto 0) := (others => '0');
    variable result : line;
    variable digit : natural;
    variable leading : boolean := true;
  begin
    padded(bits'length - 1 downto 0) := bits;
    swrite(result, "0x");
    for nibble in padded'length / 4 - 1 downto 0 loop
      digit := 0;
      for idx in 3 downto 0 loop
        digit := 2 * digit;
        if padded(4 * nibble + idx) = '1' then
          digit := digit + 1;
        end if;
      end loop;
      if digit /= 0 then
        leading := false;
      end if;
      if not leading then
        swrite(result, string'(1 => hex_digits(digit + 1)));
      end if;
    end loop;
    if leading then
      swrite(result, "0");
    end if;

    if negative then
      return "-" & result.all;
    end if;
    return result.all;
  end;

  -- The error reported for a vector value that cannot be converted
  function p_metavalue_error(value : std_logic_vector; operation : string) return string is
  begin
    return operation & " cannot convert """ & to_string(value) & """; the value has metavalues";
  end;

  impure function p_arg_value(value : unsigned; operation : string) return string is
  begin
    if p_has_metavalue(std_logic_vector(value)) then
      failure(python_logger, p_metavalue_error(std_logic_vector(value), operation));
      return "";
    end if;
    return p_to_hex_literal(to_x01(std_logic_vector(value)), false);
  end;

  impure function p_arg_value(value : signed; operation : string) return string is
    variable folded : signed(value'length - 1 downto 0);
    variable magnitude : signed(value'length downto 0);
  begin
    if p_has_metavalue(std_logic_vector(value)) then
      failure(python_logger, p_metavalue_error(std_logic_vector(value), operation));
      return "";
    end if;
    if value'length = 0 then
      return "0x0";
    end if;

    folded := signed(to_x01(std_logic_vector(value)));
    if folded(folded'left) = '0' then
      return p_to_hex_literal(std_logic_vector(folded), false);
    end if;
    -- Resizing before negating keeps the magnitude of signed'low representable
    magnitude := -resize(folded, value'length + 1);
    return p_to_hex_literal(std_logic_vector(magnitude), true);
  end;

  function arg(value : real_vector) return arg_t is
    constant text : string := p_arg_value(value, "arg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  function kwarg(kw : string; value : real_vector) return arg_t is
    constant text : string := p_arg_value(value, "kwarg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  impure function arg(value : integer_vector_ptr_t) return arg_t is
    constant text : string := p_arg_value(value, "arg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  impure function kwarg(kw : string; value : integer_vector_ptr_t) return arg_t is
    constant text : string := p_arg_value(value, "kwarg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  impure function arg(value : std_logic) return arg_t is
    constant text : string := p_arg_value(value, "arg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  impure function kwarg(kw : string; value : std_logic) return arg_t is
    constant text : string := p_arg_value(value, "kwarg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  impure function arg_unsigned(value : unsigned) return arg_t is
    constant text : string := p_arg_value(value, "arg_unsigned");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  impure function kwarg_unsigned(kw : string; value : unsigned) return arg_t is
    constant text : string := p_arg_value(value, "kwarg_unsigned");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  impure function arg_signed(value : signed) return arg_t is
    constant text : string := p_arg_value(value, "arg_signed");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  impure function kwarg_signed(kw : string; value : signed) return arg_t is
    constant text : string := p_arg_value(value, "kwarg_signed");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  -----------------------------------------------------------------------------
  -- Keyword argument groups
  -----------------------------------------------------------------------------
  -- A group of keyword arguments is a positional argument whose Python source
  -- text is **dict(a=1, b=2), spliced into the call like any other positional
  -- argument. The text of an arg(string) value is quoted and the text of the
  -- other positional values is a number, a list or a name, so none of them can
  -- be mistaken for a group.
  constant p_group_prefix : string := "**dict(";

  function p_is_group(value : arg_t) return boolean is
    alias text : string(1 to value.value'length) is value.value;
  begin
    if value.name /= p_positional_arg or text'length < p_group_prefix'length then
      return false;
    end if;
    return text(1 to p_group_prefix'length) = p_group_prefix;
  end;

  -- The keyword arguments of an operand as they are written within **dict(...)
  function p_group_items(value : arg_t) return string is
    alias text : string(1 to value.value'length) is value.value;
  begin
    if value.name = p_positional_arg then
      -- A group: drop the **dict( prefix and the trailing )
      return text(p_group_prefix'length + 1 to text'length - 1);
    end if;
    return value.name & "=" & value.value;
  end;

  impure function "&"(l, r : arg_t) return arg_t is
  begin
    if l.name = p_ignore_arg then
      return r;
    elsif r.name = p_ignore_arg then
      return l;
    elsif (l.name = p_positional_arg and not p_is_group(l)) or
          (r.name = p_positional_arg and not p_is_group(r)) then
      failure(python_logger, "Only keyword arguments can be combined with & into a keyword argument group");
      return null_arg;
    end if;

    return (p_positional_arg, p_group_prefix & p_group_items(l) & ", " & p_group_items(r) & ")");
  end;

  -----------------------------------------------------------------------------
  -- Operations implemented by the Python bridge (NVC, GHDL and Questa)
  -----------------------------------------------------------------------------
  -- Python represents std_logic values by these characters
  constant p_std_logic_characters : string(1 to 9) := "UX01ZWLH-";

  function p_to_std_logic(value : character) return std_logic is
  begin
    for idx in p_std_logic_characters'range loop
      if p_std_logic_characters(idx) = value then
        return std_logic'val(idx - 1);
      end if;
    end loop;
    -- The bridge only returns the characters above
    return 'X';
  end;

  -- The elements of the characters, the first character becoming the leftmost element
  function p_to_std_logic_vector(value : string) return std_logic_vector is
    alias normalized : string(1 to value'length) is value;
    variable result : std_logic_vector(value'length - 1 downto 0);
  begin
    for idx in normalized'range loop
      result(value'length - idx) := p_to_std_logic(normalized(idx));
    end loop;
    return result;
  end;

  -----------------------------------------------------------------------------
  -- The Python expression calling identifier with the given arguments
  -----------------------------------------------------------------------------
  function p_to_call_str(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return string is
    variable result : line;
    variable first : boolean := true;

    procedure append(value : arg_t) is
    begin
      if value.name = p_ignore_arg then
        return;
      end if;
      if not first then
        swrite(result, ", ");
      end if;
      first := false;
      if value.name = p_positional_arg then
        swrite(result, value.value);
      else
        swrite(result, value.name & "=" & value.value);
      end if;
    end;
  begin
    swrite(result, identifier & "(");
    append(arg1);
    append(arg2);
    append(arg3);
    append(arg4);
    append(arg5);
    append(arg6);
    append(arg7);
    append(arg8);
    append(arg9);
    append(arg10);
    swrite(result, ")");

    return result.all;
  end;

  -----------------------------------------------------------------------------
  -- arg and kwarg
  -----------------------------------------------------------------------------
  impure function p_arg_value(value : integer_array_t; operation : string) return string is
    constant staged_id : integer := p_stage_array(value, operation);
  begin
    if staged_id < 1 then
      return "";
    end if;
    return "__vunit__.staged(" & integer'image(staged_id) & ")";
  end;

  impure function arg(value : integer_array_t) return arg_t is
    constant text : string := p_arg_value(value, "arg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (p_positional_arg, text);
  end;

  impure function kwarg(kw : string; value : integer_array_t) return arg_t is
    constant text : string := p_arg_value(value, "kwarg");
  begin
    if text = "" then
      return null_arg;
    end if;
    return (kw, text);
  end;

  -----------------------------------------------------------------------------
  -- exec
  -----------------------------------------------------------------------------
  procedure exec_file(file_name : string; session : python_session_t := default_session) is
    variable ok : boolean;
  begin
    ok := p_exec_file(file_name, session);
  end;

  -----------------------------------------------------------------------------
  -- eval
  -----------------------------------------------------------------------------
  impure function eval_boolean(
    expr : string; session : python_session_t := default_session
  ) return boolean is
  begin
    if p_eval(expr, p_kind_boolean, -1, p_eval_operation(expr, session), session) then
      return p_result_integer /= 0;
    end if;
    return false;
  end;

  impure function eval_std_logic(
    expr : string; session : python_session_t := default_session
  ) return std_logic is
  begin
    if p_eval(expr, p_kind_std_logic, -1, p_eval_operation(expr, session), session) then
      return p_to_std_logic(p_result_string(1));
    end if;
    return 'U';
  end;

  impure function eval_std_logic_vector(
    expr : string; session : python_session_t := default_session
  ) return std_logic_vector is
  begin
    if p_eval(expr, p_kind_std_logic_vector, -1, p_eval_operation(expr, session), session) then
      return p_to_std_logic_vector(p_result_string);
    end if;
    return "";
  end;

  impure function eval_integer_array(
    expr : string; session : python_session_t := default_session
  ) return integer_array_t is
  begin
    if p_eval(expr, p_kind_integer_array, -1, p_eval_operation(expr, session), session) then
      return p_result_integer_array;
    end if;
    return null_integer_array;
  end;

  procedure eval_std_logic_vector(
    expr : string; result : out std_logic_vector; session : python_session_t := default_session
  ) is
  begin
    if p_eval(expr, p_kind_std_logic_vector, result'length, p_eval_operation(expr, session), session) then
      result := p_to_std_logic_vector(p_result_string);
    end if;
  end;

  procedure eval_signed(
    expr : string; result : out signed; session : python_session_t := default_session
  ) is
  begin
    if p_eval(expr, p_kind_signed, result'length, p_eval_operation(expr, session), session) then
      result := signed(p_to_std_logic_vector(p_result_string));
    end if;
  end;

  procedure eval_unsigned(
    expr : string; result : out unsigned; session : python_session_t := default_session
  ) is
  begin
    if p_eval(expr, p_kind_unsigned, result'length, p_eval_operation(expr, session), session) then
      result := unsigned(p_to_std_logic_vector(p_result_string));
    end if;
  end;

  -----------------------------------------------------------------------------
  -- call
  -----------------------------------------------------------------------------
  impure function call_real_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return real_vector is
  begin
    return eval_real_vector(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_string(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return string is
  begin
    return eval_string(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_integer_vector_ptr(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_vector_ptr_t is
  begin
    return eval_integer_vector_ptr(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_boolean(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return boolean is
  begin
    return eval_boolean(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_std_logic(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return std_logic is
  begin
    return eval_std_logic(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_std_logic_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return std_logic_vector is
  begin
    return eval_std_logic_vector(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  impure function call_integer_array(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) return integer_array_t is
  begin
    return eval_integer_array(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), session
    );
  end;

  procedure call_std_logic_vector(
    identifier : string; result : out std_logic_vector;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) is
  begin
    eval_std_logic_vector(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), result, session
    );
  end;

  procedure call_signed(
    identifier : string; result : out signed;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) is
  begin
    eval_signed(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), result, session
    );
  end;

  procedure call_unsigned(
    identifier : string; result : out unsigned;
    arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg;
    session : python_session_t := default_session
  ) is
  begin
    eval_unsigned(
      p_to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10), result, session
    );
  end;
end package body;
