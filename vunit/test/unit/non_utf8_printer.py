# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: skip-file
from sys import stdout

if hasattr(stdout, "buffer"):
    # Python 3
    stdout.buffer.write(b"\x87")
else:
    # Python 2.7
    stdout.write(b"\x87")

stdout.write("\n")
