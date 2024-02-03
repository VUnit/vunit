-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package python_ffi_pkg is
  procedure python_setup;
  attribute foreign of python_setup: procedure is "VHPIDIRECT python_setup";
  procedure python_cleanup;
  attribute foreign of python_cleanup: procedure is "VHPIDIRECT python_cleanup";

  function eval_integer(expr : string) return integer;
  attribute foreign of eval_integer : function is "VHPIDIRECT eval_integer";
  alias eval is eval_integer[string return integer];

  function eval_real(expr : string) return real;
  attribute foreign of eval_real : function is "VHPIDIRECT eval_real";
  alias eval is eval_real[string return real];

  function eval_integer_vector(expr : string) return integer_vector;
  alias eval is eval_integer_vector[string return integer_vector];

  function eval_real_vector(expr : string) return real_vector;
  alias eval is eval_real_vector[string return real_vector];

  function eval_string(expr : string) return string;
  alias eval is eval_string[string return string];

  procedure exec(code : string);
  attribute foreign of exec : procedure is "VHPIDIRECT exec";
end package;

package body python_ffi_pkg is
  procedure python_setup is
  begin
    report "VHPIDIRECT python_setup" severity failure;
  end;

  procedure python_cleanup is
  begin
    report "VHPIDIRECT python_cleanup" severity failure;
  end;

  function eval_integer(expr : string) return integer is
  begin
    report "VHPIDIRECT eval_integer" severity failure;
  end;

  function eval_real(expr : string) return real is
  begin
    report "VHPIDIRECT eval_real" severity failure;
  end;

  procedure get_integer_vector(vec : out integer_vector) is
    attribute foreign of get_integer_vector : procedure is "VHPIDIRECT get_integer_vector";
  begin
    report "ERROR: Failed to call foreign subprogram" severity failure;
  end;

  function eval_integer_vector(expr : string) return integer_vector is
    constant result_length : natural := eval_integer("__eval_result__.set(" & expr & ")");
    variable result : integer_vector(0 to result_length - 1);
  begin
    get_integer_vector(result);

    return result;
  end;

  procedure get_real_vector(vec : out real_vector) is
    attribute foreign of get_real_vector : procedure is "VHPIDIRECT get_real_vector";
  begin
    report "ERROR: Failed to call foreign subprogram" severity failure;
  end;

  function eval_real_vector(expr : string) return real_vector is
    constant result_length : natural := eval_integer("__eval_result__.set(" & expr & ")");
    variable result : real_vector(0 to result_length - 1);
  begin
    get_real_vector(result);

    return result;
  end;

  procedure get_py_string(vec : out string) is
    attribute foreign of get_py_string : procedure is "VHPIDIRECT get_py_string";
  begin
    report "ERROR: Failed to call foreign subprogram" severity failure;
  end;

  function eval_string(expr : string) return string is
    constant result_length : natural := eval_integer("__eval_result__.set(" & expr & ")");
    -- Add one character for the C null termination such that strcpy can be used. Do not return this
    -- character
    variable result : string(1 to result_length + 1);
  begin
    get_py_string(result);

    return result(1 to result_length);
  end;

  procedure exec(code : string) is
  begin
    report "ERROR: Failed to call foreign subprogram" severity failure;
  end;

end package body;
