-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

use work.python_ffi_pkg.all;
use work.path.all;
use work.run_pkg.all;
use work.runner_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ops.all;

use std.textio.all;

package python_pkg is
  -- TODO: Consider detecting and handling the case where the imported file
  -- has no __name__ = "__main__" guard. This is typical for run scripts and
  -- people not used to it will make mistakes.
  procedure import_module_from_file(module_path, as_module_name : string);
  procedure import_run_script(module_name : string := "");

  function to_py_list_str(vec : integer_vector) return string;
  impure function to_py_list_str(vec : integer_vector_ptr_t) return string;
  function to_py_list_str(vec : real_vector) return string;

  function "+"(l, r : string) return string;

  impure function eval_integer_vector_ptr(expr : string) return integer_vector_ptr_t;
  alias eval is eval_integer_vector_ptr[string return integer_vector_ptr_t];

  -- TODO: Questa crashes unless this function is impure
  impure function to_call_str(
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
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return integer;
  alias call is call_integer_w_arg[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t return integer];

  procedure call(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  );

  impure function call_integer_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return integer_vector;
  alias call is call_integer_vector[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t return integer_vector];

  impure function call_real(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return real;
  alias call is call_real[
    string, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t, arg_t return real];



end package;

package body python_pkg is
  -- @formatter:off
  procedure import_module_from_file(module_path, as_module_name : string) is
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
    exec(code);
  end;
  -- @formatter:on

  procedure import_run_script(module_name : string := "") is
    constant script_path : string := run_script_path(get_cfg(runner_state));
    variable path_items : lines_t;
    variable script_name : line;
  begin
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
          import_module_from_file(script_path, path_items(idx).all);
        end if;
        deallocate(path_items(idx));
      end loop;
      deallocate(path_items);
    else
      import_module_from_file(script_path, module_name);
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

  impure function eval_integer_vector_ptr(expr : string) return integer_vector_ptr_t is
    constant result_integer_vector : integer_vector := eval(expr);
    constant len : natural := result_integer_vector'length;
    constant result_integer_vector_normalized : integer_vector(0 to len - 1) := result_integer_vector;
    constant result : integer_vector_ptr_t := new_integer_vector_ptr(len);
  begin
    for idx in 0 to len - 1 loop
      set(result, idx, result_integer_vector_normalized(idx));
    end loop;

    return result;
  end;

  impure function to_call_str(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : string := ""
  ) return string is
    constant args : string := "('" & arg1 & "','" & arg2 & "','" & arg3 & "','" & arg4 & "','" & arg5 & "','" & arg6 & "','" & arg7 & "','" & arg8 & "','" & arg9 & "','" & arg10 & "')";
  begin
    return eval_string("'" & identifier & "(' + ', '.join((arg for arg in " & args & " if arg)) + ')'");
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
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return integer is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10));
  end;

  procedure call(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) is
  begin
    exec(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10));
  end;

  impure function call_integer_vector(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return integer_vector is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10));
  end;

  impure function call_real(
    identifier : string; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 : arg_t := null_arg
  ) return real is
  begin
    return eval(to_call_str(identifier, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10));
  end;
end package body;
