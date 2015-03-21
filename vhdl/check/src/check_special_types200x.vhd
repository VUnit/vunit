-- Check types specific to the VHDL 200x implementation.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;
use work.check_types_pkg.all;

package check_special_types_pkg is
  type checker_t is protected
    procedure init (
      constant default_level        : in log_level_t := error;
      constant default_src          : in string      := "";
      constant file_name            : in string      := "error.csv";
      constant default_display_mode : in log_format_t  := raw;
      constant default_file_mode    : in log_format_t  := off;
      constant stop_level : in log_level_t := failure;
      constant separator            : in character   := ',';
      constant append               : in boolean     := false);

    procedure check(expr         :    boolean;
                    msg          :    string;
                    level        :    log_level_t := dflt;
                    line_num     : in natural     := 0;
                    file_name    : in string      := "");

    impure function get_stat
      return checker_stat_t;

    procedure reset_stat;

    impure function get_cfg
      return checker_cfg_export_t;

    impure function get_logger_cfg
      return logger_cfg_export_t;

    impure function found_errors
      return boolean;

  end protected checker_t;
end package;

package body check_special_types_pkg is
  type checker_t is protected body
    variable default_log_level : log_level_t := error;
    variable stat   : checker_stat_t := (0, 0, 0);
    variable logger : logger_t;

    procedure init (
      constant default_level        : in log_level_t := error;
      constant default_src          : in string      := "";
      constant file_name            : in string      := "error.csv";
      constant default_display_mode : in log_format_t  := raw;
      constant default_file_mode    : in log_format_t  := off;
      constant stop_level : in log_level_t := failure;
      constant separator            : in character   := ',';
      constant append               : in boolean     := false) is
    begin
      default_log_level := default_level;
      logger.init(default_src, file_name, default_display_mode, default_file_mode, stop_level, separator, append);
    end init;

    procedure check(expr         :    boolean;
                    msg          :    string;
                    level        :    log_level_t := dflt;
                    line_num     : in natural     := 0;
                    file_name    : in string      := "") is
    begin
      stat.n_checks := stat.n_checks + 1;
      if (expr = false) then
        stat.n_failed := stat.n_failed + 1;
        if level = dflt then
          logger.log(msg, default_log_level, "", line_num, file_name);
        else
          logger.log(msg, level, "", line_num, file_name);
        end if;
      else
        stat.n_passed := stat.n_passed + 1;
      end if;
    end;

    impure function get_stat
      return checker_stat_t is
    begin
      return stat;
    end;

    procedure reset_stat is
    begin
      stat := (0, 0, 0);
    end reset_stat;

    impure function get_cfg
      return checker_cfg_export_t is
      variable cfg_export : checker_cfg_export_t;
    begin
      cfg_export.default_level := default_log_level;
      cfg_export.logger_cfg    := logger.get_logger_cfg;

      return cfg_export;
    end;

    impure function get_logger_cfg
      return logger_cfg_export_t is
    begin
      return logger.get_logger_cfg;
    end;

    impure function found_errors
      return boolean is
    begin
      return stat.n_failed > 0;
    end;
  end protected body checker_t;
end package body check_special_types_pkg;
