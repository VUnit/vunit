-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.print_pkg.all;
use work.common_log_pkg.all;
use work.logger_pkg.all;

library ieee;
use ieee.math_real.all;

entity tb_sim_time_formatting is
  generic(
    runner_cfg : string;
    test_time : natural := 0; -- Unit = resolution_limit
    scaling : integer := 1; -- Unit to display = scaling * resultion_limit. 0 means unit = resolution_limit
    n_decimals : integer := -1; -- -1 means full resolution (rightmost digit weight = resolution_limit)
    expected : string := ""; -- Expected result excluding unit
    auto_scaling : integer := 1; -- >1 if expected is based on this auto scaling
    n_performance_iterations : integer := 1 -- Number of itertions to run in performance testing
  );
end entity;

architecture tb of tb_sim_time_formatting is
begin
  main : process
    constant native_unit_scaling : integer := 0;
    constant auto_unit_scaling : integer := -1;

    variable unit : integer;
    variable value : time;

    function max(a, b : time) return time is
    begin
      if a > b then
        return a;
      end if;

      return b;
    end;

    function to_unit_str(unit, auto_scaling : integer) return string is
      variable log_unit : integer;
      constant first_unit_char_vec : string(1 to 5) := "fpnum";
    begin
      if scaling = auto_unit_scaling then
        log_unit := integer(log10(real(auto_scaling))) + p_resolution_limit_as_log10_of_sec;
      elsif scaling = native_unit_scaling then
        log_unit := p_resolution_limit_as_log10_of_sec;
      else
        log_unit := integer(log10(real(scaling))) + p_resolution_limit_as_log10_of_sec;
      end if;
      return first_unit_char_vec(log_unit / 3 + 6) & 's';
    end;

    function to_time(unit_as_log10_of_sec : integer) return time is
    begin
      case unit_as_log10_of_sec is
        when -15 => return fs;
        when -12 => return ps;
        when -9 => return ns;
        when -6 => return us;
        when -3 => return ms;
        when 0 => return sec;
        when others =>
          report "Value not supported: " & integer'image(unit_as_log10_of_sec) severity failure;
      end case;
    end;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test native unit") or
        run("Test units of differents scales wrt the resolution_limit") or
        run("Test auto unit") or
        run("Test limiting number of decimals") or
        run("Test full resolution") or
        run("Test trailing zeros") or
        run("Test zero") or
        run("Test random") then
        value := test_time * to_time(p_resolution_limit_as_log10_of_sec);

        if scaling = auto_unit_scaling then
          unit := p_auto_unit;
          print("p_to_string(" & time'image(value) & ", p_auto_unit, " & integer'image(n_decimals) &
            ") = " & p_to_string(value, unit, n_decimals)
          );
        elsif scaling = native_unit_scaling then
          unit := p_native_unit;
          print("p_to_string(" & time'image(value) & ", p_native_unit, " & integer'image(n_decimals) & ") = " &
            p_to_string(value, unit, n_decimals)
          );
        else
          unit := integer(log10(real(scaling))) +  p_resolution_limit_as_log10_of_sec;
          print("p_to_string(" & time'image(value) & ", " & integer'image(unit) & ", " & integer'image(n_decimals) &
            ") = " & p_to_string(value, unit, n_decimals)
          );
        end if;

        assert p_to_string(value, unit, n_decimals) = expected & " " & to_unit_str(unit, auto_scaling)
        report "Got " & p_to_string(value, unit, n_decimals) & ", expected " & expected & " " &
        to_unit_str(unit, auto_scaling)
        severity error;

      elsif run("Test image performance") then
        for iter in 1 to n_performance_iterations loop
          report time'image(123456 ps);
        end loop;

      elsif run("Test VUnit to_string performance") then
        for iter in 1 to n_performance_iterations loop
          report p_to_string(123456 ps);
        end loop;

      elsif run("Test VUnit to_string with unit performance") then
        for iter in 1 to n_performance_iterations loop
          report p_to_string(123456 ps, -9);
        end loop;

      elsif run("Test VUnit to_string with auto unit and fix decimals performance") then
        for iter in 1 to n_performance_iterations loop
          report p_to_string(123456 ps, p_auto_unit, 1);
        end loop;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
