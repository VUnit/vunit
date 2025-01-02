-- This file contains the API for the check package. The API is
-- common to all implementations of the check functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use std.textio.all;
use work.checker_pkg.all;
use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.string_ops.all;
use work.event_common_pkg.all;
use work.string_ptr_pkg.all;
use work.check_pkg.all;

package check_2008p_pkg is
  -----------------------------------------------------------------------------
  -- check_equal
  -----------------------------------------------------------------------------
  procedure check_equal(
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in ufixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  procedure check_equal(
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  procedure check_equal(
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in sfixed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  procedure check_equal(
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  -----------------------------------------------------------------------------

end package;
