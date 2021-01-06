-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.signal_checker_pkg.all;

entity tb_std_logic_checker is
  generic (
    runner_cfg : string;
    initial_monitor_enable : boolean := true;
    use_checker : boolean := false);
end entity;

architecture tb of tb_std_logic_checker is
  constant logger : logger_t := get_logger("signal_checker");

  impure function checker return checker_t is
  begin
    if use_checker then
      return new_checker("signal_checker");
    else
      return null_checker;
    end if;
  end function checker;

  constant signal_checker : signal_checker_t := new_signal_checker(logger => logger, checker => checker, initial_monitor_enable => initial_monitor_enable);

  signal value : std_logic_vector(1 downto 0);

begin
  main : process
      variable read_val : std_logic_vector(1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    show(logger, display_handler, pass);

    if run("Test error on unexpected event") then
      wait for 1 ns;
      value <= "10";

      mock(logger, error);
      wait for 1 ns;
      wait_until_idle(net, signal_checker);
      check_only_log(logger, "Unexpected event with value = " & to_string(std_logic_vector'("10")), error);
      unmock(logger);

    elsif run("Test error on wrong expected value") then
      expect(net, signal_checker, "00", 1 ns);

      wait for 1 ns;
      value <= "10";

      mock(logger, error);
      wait_until_idle(net, signal_checker);
      check_only_log(logger,
                     "Got event with wrong value, got " & to_string(std_logic_vector'("10")) &
                     " expected " & to_string(std_logic_vector'("00")), error);
      unmock(logger);

    elsif run("Test error on wrong time") then
      expect(net, signal_checker, "10", 2 ns);

      wait for 1 ns;
      value <= "10";

      mock(logger, error);
      wait_until_idle(net, signal_checker);
      check_only_log(logger,
                     "Got event at wrong time, occured at " & time'image(1 ns) &
                     " expected at " & time'image(2 ns), error);
      unmock(logger);

    elsif run("Test error wrong time margin") then
      expect(net, signal_checker, "10", 3 ns, margin => 1 ns);

      wait for 1 ns;
      value <= "10";

      mock(logger, error);
      wait_until_idle(net, signal_checker);
      check_only_log(logger,
                     "Got event at wrong time, occured at " & time'image(1 ns) &
                     " expected at " & time'image(3 ns) & " +- " & time'image(1 ns), error);
      unmock(logger);

    elsif run("Test expect single value") then

      expect(net, signal_checker, "10", 1 ns);
      wait for 1 ns;
      value <= "10";

      mock(logger, pass);
      wait_until_idle(net, signal_checker);
      if use_checker then
        check_log(logger, "Got event with wrong value, got " & to_string(std_logic_vector'("10")) & " expected 10", pass);
        check_log(logger, "Got event at wrong time, occured at " & to_string(now) & " expected at " & to_string(1 ns), pass);
      else
        check_only_log(logger, "Got expected event with value = " & to_string(std_logic_vector'("10")), pass);
      end if;
      unmock(logger);

    elsif run("Test expect single value with late margin") then

      expect(net, signal_checker, "10", 2 ns, margin => 1 ns);
      wait for 1 ns;
      value <= "10";

      mock(logger, pass);
      wait_until_idle(net, signal_checker);
      if use_checker then
        check_log(logger, "Got event with wrong value, got " & to_string(std_logic_vector'("10")) & " expected 10", pass);
        check_log(logger, "Got event at wrong time, occured at " & to_string(now) & " expected at " & to_string(2 ns) & " +- " & to_string(1 ns), pass);
      else
        check_only_log(logger, "Got expected event with value = " & to_string(std_logic_vector'("10")), pass);
      end if;
      unmock(logger);

    elsif run("Test expect single value with early margin") then

      expect(net, signal_checker, "10", 1 ns, margin => 1 ns);
      wait for 2 ns;
      value <= "10";

      mock(logger, pass);
      wait_until_idle(net, signal_checker);
      if use_checker then
        check_log(logger, "Got event with wrong value, got " & to_string(std_logic_vector'("10")) & " expected 10", pass);
        check_log(logger, "Got event at wrong time, occured at " & to_string(now) & " expected at " & to_string(1 ns) & " +- " & to_string(1 ns), pass);
      else
        check_only_log(logger, "Got expected event with value = " & to_string(std_logic_vector'("10")), pass);
      end if;
      unmock(logger);

    elsif run("Test expect multiple values") then
      expect(net, signal_checker, "10", 0 ns);
      expect(net, signal_checker, "00", 3 ns);
      expect(net, signal_checker, "ZZ", 5 ns);

      value <= "10",
               "00" after 3 ns,
               "00" after 4 ns,
               "ZZ" after 5 ns;

      wait_until_idle(net, signal_checker);

    elsif run("Test reading back the value") then
      expect(net, signal_checker, "10", 1 ns);
      wait for 1 ns;
      value <= "10";
      wait for 1 ns;
      get_value(net, signal_checker, read_val);
      check_equal(read_val, value, result(" for the readback value"));

    elsif run("Test initial checker monitor state") then
      mock(logger);
      wait for 1 ns;
      value <= "10";
      wait for 1 us;
      if initial_monitor_enable then
        wait_until_idle(net, signal_checker);
        check_only_log(logger, "Unexpected event with value = " & to_string(std_logic_vector'("10")), error);
      else
        check_no_log;
      end if;
      unmock(logger);

    elsif run("Test monitor state switch") then
      mock(logger);
      wait for 1 ns;
      value <= "10";
      wait_until_idle(net, signal_checker);
      check_only_log(logger, "Unexpected event with value = " & to_string(std_logic_vector'("10")), error);

      wait for 1 ns;
      disable_monitor(net, signal_checker);
      wait for 1 ns;
      value <= "01";
      wait for 1 ns;
      check_no_log;

      wait for 1 ns;
      enable_monitor(net, signal_checker);
      wait for 1 ns;
      value <= "11";
      wait_until_idle(net, signal_checker);
      check_only_log(logger, "Unexpected event with value = " & to_string(std_logic_vector'("11")), error);

      unmock(logger);

    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);

  dut: entity work.std_logic_checker
    generic map (
      signal_checker => signal_checker)
    port map (
      value => value);

end architecture;
