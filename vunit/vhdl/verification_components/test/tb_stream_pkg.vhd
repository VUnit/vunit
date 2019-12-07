-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_pkg.all;

entity tb_stream_pkg is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_stream_pkg is

begin

  process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("empty") then

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);

end architecture;

