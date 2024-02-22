-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.ansi_pkg.all;
use work.log_levels_pkg.all;
use work.string_ops.upper;

package common_log_pkg is
  -- Deferred constant set to true in the native implementation of the package.
  -- Must be set to false in alternative implementations.
  constant is_original_pkg : boolean;

  -- Default interface values.
  constant no_time : time := -1 ns;
  constant no_string : string := "";

  -- Converts a log message and associated metadata to a string written to the specified log destination.
  procedure write_to_log(
    ----------------------------------------------------------------------
    -- Log entry items mandatory for all implementations of this interface
    ----------------------------------------------------------------------

    -- Destination of the log message is either std.textio.output (std output) or a text file object previously opened
    -- for writing
    file log_destination : text;
    -- Path to log_destination if it's a file, empty string otherwise
    log_destination_path : string := no_string;
    -- Log message
    msg : string := no_string;
    -- Simulation time associated with the log message
    log_time : time := no_time;
    -- Level associated with the log message. For example "DEBUG" or "WARNING".
    log_level : string := no_string;
    -- Name of the producer of the log message. Hierarchical names use colon as the delimiter.
    -- For example "parent_component:child_component".
    log_source_name : string := no_string;

    -----------------------------------------------------------------------------------------------------------------
    -- Parameters specific to an implementation of this interface. Only standard IEEE, non-custom, types are allowed.
    -- The documentation below is valid for VUnit only
    -----------------------------------------------------------------------------------------------------------------

    -- Path to file from which the log entry was issued if the location is known, empty string otherwise
    log_source_path : string;
    -- Log format raw, level, verbose, or csv expressed as an integer 0 - 3.
    log_format : natural range 0 to 3;
    -- Line number in file from which the log entry was issued if the location is known, 0 otherwise
    log_source_line_number : natural;
    -- Sequence number for log entry
    log_sequence_number : natural;
    -- True if log entry is to be in color
    use_color : boolean;
    -- Max length of logger names (used for alignment)
    max_logger_name_length : natural
  );
end package;
