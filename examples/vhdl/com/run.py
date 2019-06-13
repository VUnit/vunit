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

prj = VUnit.from_argv()
prj.add_com()
prj.add_verification_components()
prj.add_osvvm()

lib = prj.add_library('lib')
lib.add_source_files(join(dirname(__file__), 'src', '*.vhd'))

tb_lib = prj.add_library('tb_lib')
tb_lib.add_source_files(join(dirname(__file__), 'test', '*.vhd'))

if __name__ == '__main__':
    prj.main()
