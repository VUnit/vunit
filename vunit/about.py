# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides documentation and version information
"""


def license_text():
    """
    Returns licence text
    """
    return """\
**VUnit**, except for the projects below, is released under the terms of `Mozilla Public License, v. 2.0`_.
|copy| 2014-2024 Lars Asplund, lars.anders.asplund@gmail.com.

The following libraries are `redistributed`_ with VUnit for convenience:

* **OSVVM** (``vunit/vhdl/osvvm``): these files are licensed under the terms of `Apache License, v 2.0`_,
  |copy| 2010 - 2023 by `SynthWorks Design Inc`_. All rights reserved.

* **JSON-for-VHDL** (``vunit/vhdl/JSON-for-VHDL``): these files are licensed under the terms of `Apache License,
  v 2.0`_, |copy| 2015 - 2022 Patrick Lehmann.

The font used in VUnit's logo and illustrations is 'Tratex', the traffic sign typeface used on swedish road signs:

- `transportstyrelsen.se: Teckensnitt <https://transportstyrelsen.se/sv/vagtrafik/Trafikregler/Om-vagmarken/Teckensnitt/>`__
- `Wikipedia: Tratex <https://en.wikipedia.org/wiki/Tratex>`__


.. |copy|   unicode:: U+000A9 .. COPYRIGHT SIGN
.. _redistributed: https://github.com/VUnit/vunit/blob/master/.gitmodules
.. _Mozilla Public License, v. 2.0: http://mozilla.org/MPL/2.0/
.. _ARTISTIC License: http://www.perlfoundation.org/artistic_license_2_0
.. _Apache License, v 2.0: http://www.apache.org/licenses/LICENSE-2.0
.. _SynthWorks Design Inc: http://www.synthworks.com
"""


def doc():
    """
    Returns short introduction to VUnit
    """
    return (
        r"""VUnit is an open source unit testing framework for VHDL/SystemVerilog
released under the terms of Mozilla Public License, v. 2.0. It
features the functionality needed to realize continuous and automated
testing of your HDL code. VUnit doesn't replace but rather complements
traditional testing methodologies by supporting a "test early and
often" approach through automation. **Read more on our**
`Website <https://vunit.github.io>`__

Contributing in the form of code, feedback, ideas or bug reports are
welcome. Read our `contribution guide
<https://vunit.github.io/contributing.html>`__ to get started.

"""
        + license_text()
    )


def version():
    """
    Returns VUnit version
    """
    return VERSION


VERSION = "5.0.0.dev6"
