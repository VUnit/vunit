# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

while {1} {
    # catch returns 1 on error, 0 on success.
    # On error, 'line' holds the error message. On success, it holds the read string.
    if {[catch {gets stdin} line]} {
        # If the OS interrupted the read, just try again
        if {[string match "*interrupted system call*" $line]} {
            continue
        } else {
            # Break on any other fatal error
            puts "Fatal error reading stdin: $line"
            break
        }
    }
    
    # Check if the Python parent process closed the pipe (EOF)
    if {[eof stdin]} {
        break
    }
    
    # Skip empty lines to prevent unnecessary eval overhead
    if {$line eq ""} {
        continue
    }

    # Evaluate the command sent from Python
    if {[catch {eval $line} error_msg]} {
        puts "$line - $error_msg"
    }
}
