# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
The fixed point model of the same integrator, executed in the fixed_point
session of tb_example.vhd. It rounds every step to a whole number, which is
what the implementation does. Both models define config and model, which is
why they need a session each.
"""

import numpy as np

config = dict(name="fixed_point", gain=0.5)


class Integrator:
    """
    An integrator accumulating gain * sample, rounded to a whole number.
    """

    def __init__(self, gain):
        self.gain = gain
        self.state = 0

    def step(self, sample):
        self.state += int(np.round(self.gain * sample))
        return float(self.state)


model = Integrator(config["gain"])
