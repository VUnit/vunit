# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
"""
Viewer handling for GHDL and NVC.
"""


class ViewerMixin:
    """
    Mixin class for handling common viewer functionality for the GHDL and NVC simulators.
    """

    __slots__ = (
        "_gui",
        "_viewer",
        "_viewer_fmt",
        "_viewer_args",
        "_gtkwave_available",
        "_surfer_available",
    )

    def __init__(self, gui, viewer, viewer_fmt, viewer_args):
        self._gui = gui
        self._viewer_fmt = viewer_fmt
        self._viewer_args = viewer_args
        self._viewer = viewer
        if gui:
            self._gtkwave_available = self.find_executable("gtkwave")
            self._surfer_available = self.find_executable("surfer")

    def _get_viewer(self, config):
        """
        Determine the waveform viewer to use.

        Falls back to gtkwave or surfer, in that order, if none is provided.
        """
        viewer = self._viewer or config.sim_options.get(self.name + ".viewer.gui", None)

        if viewer is None:
            if self._gtkwave_available:
                viewer = "gtkwave"
            elif self._surfer_available:
                viewer = "surfer"
            else:
                raise RuntimeError("No viewer found. GUI not possible. Install GTKWave or Surfer.")

        elif not self.find_executable(viewer):
            viewers = []
            if self._gtkwave_available:
                viewers += ["gtkwave"]
            if self._surfer_available:
                viewers += ["surfer"]
            addendum = f" The following viewer(s) are found in the path: {', '.join(viewers)}" if viewers else ""
            raise RuntimeError(
                f"Cannot find the {viewer} executable in the PATH environment variable. GUI not possible.{addendum}"
            )
        return viewer
