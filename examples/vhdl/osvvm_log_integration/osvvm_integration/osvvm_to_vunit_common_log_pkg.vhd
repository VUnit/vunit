-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
    log_source_name : string := no_string
  );
end package;
