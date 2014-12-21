# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import join, normpath, splitext, basename
from os import walk
from re import compile

class TestLicense(unittest.TestCase):
    def test_that_a_license_notice_exists_in_every_source_file(self):
        license_notice = compile(r"""(?P<comment_start>#|--|//) This Source Code Form is subject to the terms of the Mozilla Public
(?P=comment_start) License, v\. 2\.0\. If a copy of the MPL was not distributed with this file,
(?P=comment_start) You can obtain one at http://mozilla\.org/MPL/2\.0/\.
(?P=comment_start)
(?P=comment_start) Copyright \(c\) (?P<year>20\d\d), Lars Asplund lars\.anders\.asplund@gmail\.com""")
        for root, dirs, files in walk(normpath(join(__file__, '..', '..'))):
            for f in files:
                if 'preprocessed' in root:
                    continue
                if splitext(f)[1] in ['.vhd', '.vhdl', '.py', '.v', '.sv']:
                    with open(join(root, f)) as fp:
                        code = fp.read()
                        match = license_notice.search(code)
                        self.assertIsNotNone(match, "Failed to find license notice in %s" % join(root,f))   
                        self.assertGreaterEqual(int(match.group('year')),
                                                2014, "%s is not a valid copyright year" % match.group('year'))

