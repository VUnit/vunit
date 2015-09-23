# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from distutils.core import setup
import os


def find_all_files(directory):
    """
    Recursively find all files within directory
    """
    result = []
    for root, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            result.append(os.path.join(root, filename))
    return result

data_files = (find_all_files('vhdl') +
              find_all_files('verilog'))

# Makes data folder appear one directory level up from the vunit package in the installed system folder.
# This is required since references are made with the source directory layout in mind
# @TODO This is not very nice and could potentially cause problems,
#       we should move the data folders into the vunit package folder to keep locality
data_files = [os.path.join("..", i) for i in data_files]

setup(
    name='vunit_hdl',
    version='v0.37.0',
    packages=['vunit',
              'vunit.com',
              'vunit.test',
              'vunit.parsing',
              'vunit.parsing.verilog',
              'vunit.test.lint',
              'vunit.test.unit',
              'vunit.test.acceptance'],
    package_data={'vunit': data_files},
    url='https://github.com/LarsAsplund/vunit',
    classifiers=['Development Status :: 5 - Production/Stable',
                 'License :: OSI Approved :: Mozilla Public License 2.0 (MPL 2.0)',
                 'Natural Language :: English',
                 'Intended Audience :: Developers',
                 'Programming Language :: Python :: 2.7',
                 'Programming Language :: Python :: 3.3',
                 'Programming Language :: Python :: 3.4',
                 'Programming Language :: Python :: 3.5',
                 'Operating System :: Microsoft :: Windows',
                 'Operating System :: MacOS :: MacOS X',
                 'Operating System :: POSIX :: Linux',
                 'Topic :: Software Development :: Testing'],
    author='Lars Asplund',
    author_email='lars.anders.asplund@gmail.com',
    description="VUnit is an open source unit testing framework for VHDL/SystemVerilog.",
    long_description="""VUnit is an open source unit testing framework for VHDL/SystemVerilog released under the terms of Mozilla Public License, v. 2.0. It features the functionality needed to realize continuous and automated testing of your VHDL code. VUnit doesn't replace but rather complements traditional testing methodologies by supporting a "test early and often" approach through automation.""")  # nopep8
