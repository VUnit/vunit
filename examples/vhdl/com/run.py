# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Communication library
---------------------

Demonstrates the ``com`` message passing package which can be used
to communicate arbitrary objects between processes.  Further reading
can be found in the :ref:`com user guide <com_user_guide>`.
"""

from os.path import join, dirname
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_com()
vu.add_verification_components()
vu.add_osvvm()

vu.add_library('lib').add_source_files(join(dirname(__file__), 'src', '*.vhd'))
vu.add_library('tb_lib').add_source_files(join(dirname(__file__), 'test', '*.vhd'))

vu.main()
