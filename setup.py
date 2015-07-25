# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from distutils.core import setup
import glob
import os

vhdl_files = []
directories = glob.glob('vhdl')
directories += glob.glob(os.path.join('vhdl', 'vhdl', 'src', 'lang'))
directories += glob.glob(os.path.join('vhdl', 'vhdl', 'src', 'lib', 'std'))
directories += glob.glob(os.path.join('vhdl', 'array', 'src'))
directories += glob.glob(os.path.join('vhdl', 'check', 'src'))
directories += glob.glob(os.path.join('vhdl', 'com', 'src'))
directories += glob.glob(os.path.join('vhdl', 'dictionary', 'src'))
directories += glob.glob(os.path.join('vhdl', 'logging', 'src'))
directories += glob.glob(os.path.join('vhdl', 'osvvm'))
directories += glob.glob(os.path.join('vhdl', 'run', 'src'))
directories += glob.glob(os.path.join('vhdl', 'path', 'src'))
directories += glob.glob(os.path.join('vhdl', 'string_ops', 'src'))
for directory in directories:
    vhdl_files += glob.glob(os.path.join(directory, '*.vhd'))
vhdl_files = [os.path.join("..", i) for i in vhdl_files]

setup(
    name='vunit',
    version='v0.26.0',
    packages=['vunit', 'vunit.com', 'vunit.test', 'vunit.test.lint', 'vunit.test.unit', 'vunit.test.acceptance'],
    package_data={'vunit': vhdl_files},
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
    description="VUnit is an open source unit testing framework for VHDL.",
    long_description="""VUnit is an open source unit testing framework for VHDL released under the terms of Mozilla Public License, v. 2.0. It features the functionality needed to realize continuous and automated testing of your VHDL code. VUnit doesn't replace but rather complements traditional testing methodologies by supporting a "test early and often" approach through automation.""")  # nopep8
