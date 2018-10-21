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
      if run("") then

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);

end architecture;

