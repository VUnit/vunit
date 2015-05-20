-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;

entity logging_synthesis_test is
  port (
    clk : in  std_logic;
    d : in  std_logic;
    q : out std_logic);
end entity logging_synthesis_test;

architecture synth of logging_synthesis_test is

begin
  logging: process (clk) is
    variable logger_cfg : logger_cfg_t;
    variable logger_cfg_export : logger_cfg_export_t;
    variable filter : log_filter_t;
    variable my_logger : logger_t;
  begin
    if rising_edge(clk) then
      q <= d;

      logger_init("foo");
      get_logger_cfg(logger_cfg);
      get_logger_cfg(logger_cfg_export);
      stop_level(info, display_handler, filter);
      stop_level((info, debug), display_handler, filter);
      pass_level(info, display_handler, filter);
      pass_level((info, debug), display_handler, filter);
      stop_source("foo", display_handler, filter);
      pass_source("foo", display_handler, filter);
      stop_level(info, (display_handler, file_handler), filter);
      stop_level((info, debug), (display_handler, file_handler), filter);
      pass_level(info, (display_handler, file_handler), filter);
      pass_level((info, debug), (display_handler, file_handler), filter);
      stop_source("foo", (display_handler, file_handler), filter);
      pass_source("foo", (display_handler, file_handler), filter);
      remove_filter(filter);
      rename_level(info_high1, "important info");

      info("Hello World");
      log("Hello World");
      verbose_high2("Hello World");
      verbose_high1("Hello World");
      verbose("Hello World");
      verbose_low1("Hello World");
      verbose_low2("Hello World");
      debug_high2("Hello World");
      debug_high1("Hello World");
      debug("Hello World");
      debug_low1("Hello World");
      debug_low2("Hello World");
      info_high2("Hello World");
      info_high1("Hello World");
      info("Hello World");
      info_low1("Hello World");
      info_low2("Hello World");
      warning_high2("Hello World");
      warning_high1("Hello World");
      warning("Hello World");
      warning_low1("Hello World");
      warning_low2("Hello World");
      error_high2("Hello World");
      error_high1("Hello World");
      error("Hello World");
      error_low1("Hello World");
      error_low2("Hello World");
      failure_high2("Hello World");
      failure_high1("Hello World");
      failure("Hello World");
      failure_low1("Hello World");
      failure_low2("Hello World");

      logger_init(my_logger, "bar");
      get_logger_cfg(my_logger, logger_cfg);
      get_logger_cfg(my_logger, logger_cfg_export);
      stop_level(my_logger, info, display_handler, filter);
      stop_level(my_logger, (info, debug), display_handler, filter);
      pass_level(my_logger, info, display_handler, filter);
      pass_level(my_logger, (info, debug), display_handler, filter);
      stop_source(my_logger, "foo", display_handler, filter);
      pass_source(my_logger, "foo", display_handler, filter);
      stop_level(my_logger, info, (display_handler, file_handler), filter);
      stop_level(my_logger, (info, debug), (display_handler, file_handler), filter);
      pass_level(my_logger, info, (display_handler, file_handler), filter);
      pass_level(my_logger, (info, debug), (display_handler, file_handler), filter);
      stop_source(my_logger, "foo", (display_handler, file_handler), filter);
      pass_source(my_logger, "foo", (display_handler, file_handler), filter);
      remove_filter(my_logger, filter);
      rename_level(my_logger, info_high1, "important info");

      info(my_logger, "Hello World");
      log(my_logger, "Hello World");
      verbose_high2(my_logger, "Hello World");
      verbose_high1(my_logger, "Hello World");
      verbose(my_logger, "Hello World");
      verbose_low1(my_logger, "Hello World");
      verbose_low2(my_logger, "Hello World");
      debug_high2(my_logger, "Hello World");
      debug_high1(my_logger, "Hello World");
      debug(my_logger, "Hello World");
      debug_low1(my_logger, "Hello World");
      debug_low2(my_logger, "Hello World");
      info_high2(my_logger, "Hello World");
      info_high1(my_logger, "Hello World");
      info(my_logger, "Hello World");
      info_low1(my_logger, "Hello World");
      info_low2(my_logger, "Hello World");
      warning_high2(my_logger, "Hello World");
      warning_high1(my_logger, "Hello World");
      warning(my_logger, "Hello World");
      warning_low1(my_logger, "Hello World");
      warning_low2(my_logger, "Hello World");
      error_high2(my_logger, "Hello World");
      error_high1(my_logger, "Hello World");
      error(my_logger, "Hello World");
      error_low1(my_logger, "Hello World");
      error_low2(my_logger, "Hello World");
      failure_high2(my_logger, "Hello World");
      failure_high1(my_logger, "Hello World");
      failure(my_logger, "Hello World");
      failure_low1(my_logger, "Hello World");
      failure_low2(my_logger, "Hello World");

    end if;
  end process logging;
end architecture synth;


