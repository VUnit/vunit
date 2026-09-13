-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- The behaviour of this component is a Python function, loaded from
-- model_file. The VHDL only passes values between the ports and the model.

library vunit_lib;
context vunit_lib.python_context;

entity python_model is
  generic(model_file : string);
  port(
    x : in integer;
    y : out integer
  );
end entity;

architecture python of python_model is
begin
  model : process is
  begin
    -- Wait for the first input so that the model is only loaded if used
    wait on x;
    exec_file(model_file);

    loop
      y <= call("compute", arg(x));
      wait on x;
    end loop;
  end process;
end architecture;
