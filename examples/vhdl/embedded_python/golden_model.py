# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
The golden model of an integrator, executed in the golden session of
tb_example.vhd. It computes in full precision.
"""

config = dict(name="golden", gain=0.5)


class Integrator:
    """
    An integrator accumulating gain * sample.
    """

    def __init__(self, gain):
        self.gain = gain
        self.state = 0.0

    def step(self, sample):
        self.state += self.gain * sample
        return self.state


model = Integrator(config["gain"])
