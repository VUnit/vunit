# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

# pylint: skip-file
from sys import stdout

if hasattr(stdout, "buffer"):
    # Python 3
    stdout.buffer.write(b'a' + b"\x87" + b'c')
else:
    # Python 2.7
    stdout.write(b'a' + b"\x87" + b'c')

stdout.write("\n")
