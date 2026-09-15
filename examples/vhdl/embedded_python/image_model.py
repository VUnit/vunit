# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Image processing with NumPy, imported from VHDL with import_module_from_file.
"""

import numpy as np


def transpose(image):
    """
    The transpose of a 2-D image, computed by NumPy.
    """
    return np.ascontiguousarray(image.T)


def pixel(image, x, y):
    """
    The pixel in column x of row y. VHDL get(a, x, y) is Python a[y, x].
    """
    return int(image[y, x])
