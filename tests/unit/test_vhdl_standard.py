# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the vhdl_standard.py file
"""

from vunit.vhdl_standard import VHDL


def test_valid_standards():
    for std in ["93", "02", "08", "19", "1993", "2002", "2008", "2019"]:
        VHDL.standard(std)


def test_error_on_invalid_standard():
    _assert_is_invalid("2001")
    _assert_is_invalid("002")
    _assert_is_invalid("993")
    _assert_is_invalid("2")
    _assert_is_invalid("3")


def test_equality():
    assert VHDL.standard("2008") == VHDL.standard("2008")
    assert VHDL.standard("1993") != VHDL.standard("2008")
    assert VHDL.standard("93") == VHDL.standard("1993")


def test_comparison():
    assert VHDL.standard("1993") < VHDL.standard("2002")
    assert VHDL.standard("2002") < VHDL.standard("2008")
    assert VHDL.standard("2008") < VHDL.standard("2019")


def test_str():
    assert str(VHDL.standard("1993")) == "93"
    assert str(VHDL.standard("2002")) == "2002"


def test_and_later():
    assert VHDL.STD_1993.and_later == {
        VHDL.STD_1993,
        VHDL.STD_2002,
        VHDL.STD_2008,
        VHDL.STD_2019,
    }
    assert VHDL.STD_2002.and_later == {
        VHDL.STD_2002,
        VHDL.STD_2008,
        VHDL.STD_2019,
    }
    assert VHDL.STD_2008.and_later == {VHDL.STD_2008, VHDL.STD_2019}
    assert VHDL.STD_2019.and_later == {VHDL.STD_2019}


def test_and_earlier():
    assert VHDL.STD_2019.and_earlier == {
        VHDL.STD_1993,
        VHDL.STD_2002,
        VHDL.STD_2008,
        VHDL.STD_2019,
    }
    assert VHDL.STD_2008.and_earlier == {VHDL.STD_1993, VHDL.STD_2002, VHDL.STD_2008}
    assert VHDL.STD_2002.and_earlier == {VHDL.STD_1993, VHDL.STD_2002}
    assert VHDL.STD_1993.and_earlier == {VHDL.STD_1993}


def test_supports_context():
    assert not VHDL.STD_2002.supports_context
    assert VHDL.STD_2008.supports_context


def _assert_is_invalid(standard_string):
    """
    Check that the standard string produces an exception
    """
    try:
        VHDL.standard(standard_string)
    except ValueError:
        pass
    else:
        raise AssertionError("Exception not raised")
