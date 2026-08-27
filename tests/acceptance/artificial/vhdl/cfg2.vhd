-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

configuration cfg2 of tb_with_vhdl_configuration is
  for tb
    for ent_inst : ent
      use entity work.ent(arch2);
    end for;
  end for;
end;
