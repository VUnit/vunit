-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package common_log_pkg is
  -- Deferred constant set to true in the native implementation of the package.
  -- Must be set to false in alternative implementations.
  constant is_original_pkg : boolean;

  -- Default interface values.
  constant no_time : time := -1 ns;
  constant no_string : string := "";

  -- Converts a log message and associated metadata to a string written to the specified log destination.
  procedure write_to_log(
    ----------------------------------------------------
    -- Log entry items common to many logging frameworks
    ----------------------------------------------------

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

    ----------------------------------------------------------------------------------------------------------------------------
    -- Log entry items less commonly used are passed to the procedure with no-name string and integer parameters which
    -- meaning is specific to an implementation of the procedure. The documentation below is valid for VUnit only
    ----------------------------------------------------------------------------------------------------------------------------

    str_1, -- File name from which the log entry was issued if the location is known, empty string otherwise

    str_2, str_3, str_4, str_5, str_6, str_7, str_8, str_9, str_10 : string := ""; -- Not used

    int_1, -- Log format raw, level, verbose, or csv expressed as an integer 0 - 3.
    int_2, -- Line number in file from which the log entry was issued if the location is known, 0 otherwise
    int_3, -- Sequence number for log entry
    int_4, -- 1 if log entry is to be in color, 0 otherwise
    int_5, -- Max length of logger names (used for alignment)

    int_6, int_7, int_8, int_9, int_10 : integer := 0; -- Not used

    bool_1, bool_2, bool_3, bool_4, bool_5, bool_6, bool_7, bool_8, bool_9, bool_10 : boolean := false -- Not used
  );
end package;
