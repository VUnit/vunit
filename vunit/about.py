# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides documentation and version information
"""


def license_text():
    """
    Returns licence text
    """
    return """VUnit
-----

VUnit except for OSVVM (see below) is released under the terms of
Mozilla Public License, v. 2.0.

Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

OSVVM
-----

OSVVM is redistributed as a submodule to VUnit for your convenience. OSVVM and derivative work
located under examples/vhdl/osvvm_integration/src are licensed under the terms of Artistic License 2.0.

Copyright (c) 2006-2016, SynthWorks Design Inc http://www.synthworks.com
"""


def doc():
    """
    Returns short introduction to VUnit
    """
    return r"""What is VUnit?
==============

VUnit is an open source unit testing framework for VHDL/SystemVerilog
released under the terms of Mozilla Public License, v. 2.0. It
features the functionality needed to realize continuous and automated
testing of your HDL code. VUnit doesn't replace but rather complements
traditional testing methodologies by supporting a "test early and
often" approach through automation.

**Read more on our** `Website <https://vunit.github.io>`__

License
=======
""" + license_text()


def version():
    """
    Returns VUnit version
    """
    return '0.70.0'
