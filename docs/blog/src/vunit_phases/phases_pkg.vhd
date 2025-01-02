-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

package phases_pkg is
  constant logger : logger_t := get_logger("tb_phases");
  constant phase_level : log_level_t := new_log_level("phase", fg => white);

  signal reset : std_logic;
  signal error_flag : std_logic := '0';

  procedure phase(name, description : string);
end;

package body phases_pkg is
  procedure phase(name, description : string) is
    type ansi_color_vec_t is array (runner_phase_t range <>) of ansi_color_t;
    constant colors : ansi_color_vec_t(test_runner_setup to test_runner_cleanup) := (cyan, white, lightblue, magenta, green, yellow, red);
    variable result : line;

    procedure add_bar is
      variable words : lines_t := split(name, " ");
      variable real_phase_name : line;
      variable real_phase : runner_phase_t;
      variable column : natural;
    begin
      for idx in words'range loop
        write(real_phase_name, lower(words(idx).all));
        if idx /= words'right then
          swrite(real_phase_name, "_");
        end if;
      end loop;
      real_phase := runner_phase_t'value(real_phase_name.all);
      column := runner_phase_t'pos(real_phase) - 1;

      if column > 0 then
        swrite(result, (1 to column => ' '));
      end if;
      write(result, colorize(" ", bg => colors(real_phase)));
      if column < 8 then
        swrite(result, (1 to 8 - column => ' '));
      end if;
    end;

    impure function wrap(description : string) return string is
      variable result : line;
      variable words : lines_t := split(description, " ");
      constant max_length : natural := 75;
      variable length : natural := 0;
    begin
      for idx in words'range loop
        if length + words(idx).all'length <= max_length then
          swrite(result, words(idx).all & " ");
          length := length + words(idx).all'length + 1;
        else
          swrite(result, LF & words(idx).all & " ");
          length := words(idx).all'length + 1;
        end if;
      end loop;

      return result.all;
    end;

    variable lines : lines_t := split(wrap(description), (1 => LF));
  begin
    add_bar;
    write(result, colorize(name, fg => lightgreen, style => bright));
    write(result, LF);
    for idx in lines'range loop
      add_bar;
      write(result, lines(idx).all);
      write(result, LF);
    end loop;

    log(logger,  result.all, phase_level);
  end;
end;
