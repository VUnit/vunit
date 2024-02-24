# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

while {1} {
    set line [gets stdin]
    if {[catch {eval $line} error_msg]} {
        puts "$line - $error_msg"
    }
}
