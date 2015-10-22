-- Log types specific to the VHDL 93 implementation.
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

package log_special_types_pkg is
  type level_names_t is array (log_level_t range <>) of line;
  type list_entry_t is record
    active : boolean;
    filter : log_filter_t;
  end record;
  type list_t is array (natural range <>) of list_entry_t;

  type logger_t is record
    log_default_src          : line;
    log_file_name            : line;
    log_display_format : log_format_t;
    log_file_format    : log_format_t;
    log_file_is_initialized  : boolean;
    log_stop_level          : log_level_t;
    log_separator            : character;
    log_level_names : level_names_t(failure_high2 to verbose_low2);
    log_filter_list : list_t(1 to 10);
    log_filter_list_tail : natural;
    log_filter_id : natural;
  end record;

  impure function get_seq_num
    return natural;
end package;

package body log_special_types_pkg is
  shared variable global_sequence_number : natural := 0;

  impure function get_seq_num
    return natural is
    variable ret_val : natural;
  begin
    ret_val := global_sequence_number;
    global_sequence_number := global_sequence_number + 1;
    return ret_val;
  end;
end package body log_special_types_pkg;
