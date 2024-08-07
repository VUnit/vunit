-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package python_ffi_pkg is
  procedure python_setup;
  -- TODO: Looks like Riviera-PRO requires the path to the shared library to be fixed at compile time
  -- and that may become a bit limited. VHDL standard allow for expressions.
  attribute foreign of python_setup : procedure is "VHPI libraries/python; python_setup";
  procedure python_cleanup;
  attribute foreign of python_cleanup : procedure is "VHPI libraries/python; python_cleanup";

  function eval_integer(expr : string) return integer;
  attribute foreign of eval_integer : function is "VHPI libraries/python; eval_integer";
  alias eval is eval_integer[string return integer];

  function eval_real(expr : string) return real;
  attribute foreign of eval_real : function is "VHPI libraries/python; eval_real";
  alias eval is eval_real[string return real];

  function eval_integer_vector(expr : string) return integer_vector;
  attribute foreign of eval_integer_vector : function is "VHPI libraries/python; eval_integer_vector";
  alias eval is eval_integer_vector[string return integer_vector];

  function eval_real_vector(expr : string) return real_vector;
  attribute foreign of eval_real_vector : function is "VHPI libraries/python; eval_real_vector";
  alias eval is eval_real_vector[string return real_vector];

  function eval_string(expr : string) return string;
  attribute foreign of eval_string : function is "VHPI libraries/python; eval_string";
  alias eval is eval_string[string return string];

  procedure exec(code : string);
  attribute foreign of exec : procedure is "VHPI libraries/python; exec";
end package;

package body python_ffi_pkg is
end package body;
