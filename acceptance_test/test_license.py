# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import join, normpath, splitext
from os import walk
from re import compile
from subprocess import Popen, PIPE, STDOUT
from sys import stdout

class TestLicense(unittest.TestCase):
    def test_that_a_valid_license_notice_exists_in_every_source_file_and_that_global_licensing_information_is_correct(self):
        license_notice = compile(r"""(?P<comment_start>#|--|//) This Source Code Form is subject to the terms of the Mozilla Public
(?P=comment_start) License, v\. 2\.0\. If a copy of the MPL was not distributed with this file,
(?P=comment_start) You can obtain one at http://mozilla\.org/MPL/2\.0/\.
(?P=comment_start)
(?P=comment_start) Copyright \(c\) (?P<first_year>20\d\d)(-(?P<last_year>20\d\d))?, Lars Asplund lars\.anders\.asplund@gmail\.com""")
        log_date = compile(r'Date:\s*(?P<year>20\d\d)-\d\d-\d\d')
        licensed_files = []
        for root, dirs, files in walk(normpath(join(__file__, '..', '..'))):
            for f in files:
                if 'preprocessed' in root:
                    continue
                if splitext(f)[1] in ['.vhd', '.vhdl', '.py', '.v', '.sv']:
                    licensed_files.append(join(root, f))
        i = 0
        min_first_year = None
        max_last_year = None
        for f in licensed_files:
            stdout.write('\r%d/%d' % (i + 1, len(licensed_files)))
            stdout.flush()
            i += 1
            proc = Popen(['git', 'log',  '--follow', '--date=short', f], \
                  bufsize=0, stdout=PIPE, stdin=PIPE, stderr=STDOUT, universal_newlines=True)
            out, _ = proc.communicate()
            first_year = None
            last_year = None
            for date in log_date.finditer(out):
                first_year = int(date.group('year')) if first_year is None else min(int(date.group('year')), first_year)
                last_year = int(date.group('year')) if last_year is None else max(int(date.group('year')), last_year)
            min_first_year = first_year if min_first_year is None else min(min_first_year, first_year)
            max_last_year = last_year if max_last_year is None else max(max_last_year, last_year)

            with open(f) as fp:
                code = fp.read()
                match = license_notice.search(code)
                self.assertIsNotNone(match, "Failed to find license notice in %s" % f)
                if first_year == last_year:
                    self.assertEqual(int(match.group('first_year')), first_year, 'Expected copyright year to be %d in %s' % (first_year, f)) 
                    self.assertIsNone(match.group('last_year'), 'Expected no copyright years range in %s' % join(root, f))
                else:
                    self.assertIsNotNone(match.group('last_year'), 'Expected copyright year range %d-%d in %s' % (first_year, last_year, f))
                    self.assertEqual(int(match.group('first_year')), first_year, 'Expected copyright year range to start with %d in %s' % (first_year, f)) 
                    self.assertEqual(int(match.group('last_year')), last_year, 'Expected copyright year range to end with %d in %s' % (last_year, f))
        print('\n')
                            
                        

