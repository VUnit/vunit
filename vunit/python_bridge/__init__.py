# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com


"""
VHDL-to-Python bridge enabled by ``add_python()``.

The bridge is a small C library (native/*.c) that embeds CPython in the
simulator process and is called from VHDL through VHPIDIRECT foreign
subprograms. It is the NVC/GHDL implementation of ``python_ffi_pkg``, the
private engine below the public ``python_pkg`` API. Modules:

* bridge: setup of a project (called by add_python).
* native_library: compiles and caches the library on Linux, selects the
  prebuilt DLL on Windows.
* simulator_hooks: makes NVC and GHDL find the library.
* runtime: runs inside the simulator's embedded interpreter.

Nothing in this package runs unless Python support is explicitly requested.
"""
