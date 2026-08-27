-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

configuration test_state_change_behavioral of tb_selecting_test_runner_with_vhdl_configuration is
  for tb
    for test_runner_inst : test_runner
      use entity work.test_runner(test_state_change_a);
    end for;

    for test_fixture
      for dut : dff
        use entity work.dff(behavioral);
      end for;
    end for;
  end for;
end;
