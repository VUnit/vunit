-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

context work.vunit_context;
context work.com_context;
use work.signal_driver_pkg.all;

entity tb_std_logic_driver is
  generic (
    runner_cfg : string
    );
end entity tb_std_logic_driver;

architecture tb of tb_std_logic_driver is
  constant logger        : logger_t        := get_logger("signal_driver");
  constant checker       : checker_t       := new_checker(logger);
  constant signal_driver : signal_driver_t := new_signal_driver(initial => "0010", logger => logger);

  signal clk   : std_logic := '1';
  signal value : std_logic_vector(3 downto 0);
begin
  main : process is
    variable t : time;
  begin
    test_runner_setup(runner, runner_cfg);
    show(logger, display_handler, pass);

    if run("Test default") then
      check_equal(checker, value, std_logic_vector'("0010"), "Incorrect initial value");

    elsif run("Test single value") then
      wait until rising_edge(clk);
      wait for 7 ns;
      drive(net, signal_driver, std_logic_vector'("0011"));
      wait until value'event;
      check_equal(checker, value, std_logic_vector'("0011"), "Incorrect value");
      check_equal(checker, clk'last_event, 0 ns, "Value did not change on clock edge");

    elsif run("Test single value at clock edge") then
      wait until rising_edge(clk);
      t := now;
      drive(net, signal_driver, std_logic_vector'("0100"));
      wait until value'event;
      check_equal(checker, value, std_logic_vector'("0100"), "Incorrect value");
      check_equal(checker, t, now, "Value did not change on the same clock edge as scheduled");

    elsif run("Test multiple values") then
      wait until rising_edge(clk);
      for i in 5 to 14 loop
        drive(net, signal_driver, std_logic_vector(to_unsigned(i, 4)));
      end loop;
      for i in 5 to 14 loop
        wait for 1 ps;
        check_equal(checker, value, std_logic_vector(to_unsigned(i, 4)));
        wait until rising_edge(clk);
      end loop;

    elsif run("Test waiting") then
      wait until rising_edge(clk);
      for i in 5 to 14 loop
        drive(net, signal_driver, std_logic_vector(to_unsigned(i, 4)));
      end loop;
      wait_until_idle(net, signal_driver);
      check_equal(checker, value, std_logic_vector'("1110"), "Correct value when idle");
      check_equal(checker, now, 100 ns, "Idle after 10 clocks");

    end if;

    test_runner_cleanup(runner);
  end process;


  inst_std_logic_driver : entity work.std_logic_driver
    generic map (
      signal_driver => signal_driver
      )
    port map (
      clk   => clk,
      value => value
      );

  clk <= not clk after 5 ns;

  test_runner_watchdog(runner, 1 us);
end architecture tb;

