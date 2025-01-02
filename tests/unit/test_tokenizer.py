# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the general tokenizer
"""

from unittest import TestCase
from unittest import mock
from vunit.parsing.tokenizer import describe_location


class TestTokenizer(TestCase):
    """
    Test of the general tokenizer
    """

    def test_describes_single_char_location(self):
        self.assertEqual(
            _describe_location(
                """\
S
"""
            ),
            """\
at filename0 line 1:
S
~""",
        )

    def test_describes_single_char_location_within(self):
        self.assertEqual(
            _describe_location(
                """\
  S
"""
            ),
            """\
at filename0 line 1:
  S
  ~""",
        )

    def test_describes_multi_char_location(self):
        self.assertEqual(
            _describe_location(
                """\
S E
"""
            ),
            """\
at filename0 line 1:
S E
~~~""",
        )

    def test_describes_multi_char_location_within(self):
        self.assertEqual(
            _describe_location(
                """\
  S E
"""
            ),
            """\
at filename0 line 1:
  S E
  ~~~""",
        )

    def test_describes_multi_line_location(self):
        self.assertEqual(
            _describe_location(
                """\
  S____
 E
"""
            ),
            """\
at filename0 line 1:
  S____
  ~~~~~""",
        )

    def test_describes_multi_file_location(self):
        self.assertEqual(
            _describe_location(
                """\

  S__E""",
                """\


  SE""",
            ),
            """\
from filename0 line 2:
  S__E
  ~~~~
at filename1 line 3:
  SE
  ~~""",
        )

    def test_describe_location_none(self):
        self.assertEqual(describe_location(None), "Unknown location")

    def test_describe_missing_location(self):
        self.assertEqual(
            describe_location((("missing.svh", (0, 0)), None)),
            "Unknown location in missing.svh",
        )

    def test_describe_none_filename_location(self):
        self.assertEqual(describe_location(((None, (0, 0)), None)), "Unknown Python string")


def _describe_location(*codes):
    """
    Helper to test describe_location
    """
    contents = {}
    location = None
    for idx, code in enumerate(codes):
        filename = "filename%i" % idx
        contents[filename] = code
        start = code.index("S")

        if "E" in code:
            end = code.index("E")
        else:
            end = start

        location = ((filename, (start, end)), location)

    with mock.patch("vunit.parsing.tokenizer.read_file", autospec=True) as mock_read_file:
        with mock.patch("vunit.parsing.tokenizer.file_exists", autospec=True) as mock_file_exists:

            def file_exists_side_effect(filename):
                return filename in contents

            def read_file_side_effect(filename):
                return contents[filename]

            mock_file_exists.side_effect = file_exists_side_effect
            mock_read_file.side_effect = read_file_side_effect

            retval = describe_location(location=location)
            return retval
