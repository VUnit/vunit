# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the database related classes
"""

import unittest
from pathlib import Path
from tests.common import with_tempdir
from vunit.database import DataBase, PickledDataBase


class TestDataBase(unittest.TestCase):
    """
    The the byte based database
    """

    key1 = b"key2"
    key2 = b"key1"
    value1 = b"value1"
    value2 = b"value2"

    @staticmethod
    def create_database(tempdir, new=False):
        return DataBase(str(Path(tempdir) / "database"), new=new)

    def _test_add_items(self, tempdir):
        """
        Re-usable test case
        """
        database = self.create_database(tempdir)

        self.assertTrue(self.key1 not in database)
        self.assertTrue(self.key2 not in database)
        database[self.key1] = self.value1

        self.assertTrue(self.key1 in database)
        self.assertTrue(self.key2 not in database)
        self.assertEqual(database[self.key1], self.value1)

        database[self.key2] = self.value2
        self.assertTrue(self.key1 in database)
        self.assertTrue(self.key2 in database)
        self.assertEqual(database[self.key1], self.value1)
        self.assertEqual(database[self.key2], self.value2)

    @with_tempdir
    def test_add_items(self, tempdir):
        self._test_add_items(tempdir)

    @with_tempdir
    def test_is_persistent(self, tempdir):
        self._test_add_items(tempdir)
        database = self.create_database(tempdir)
        self.assertEqual(database[self.key1], self.value1)
        self.assertEqual(database[self.key2], self.value2)

    @with_tempdir
    def test_new_database_is_created(self, tempdir):
        self._test_add_items(tempdir)
        database = self.create_database(tempdir, new=True)
        self.assertTrue(self.key1 not in database)
        self.assertTrue(self.key2 not in database)

    @with_tempdir
    def test_missing_key_raises_keyerror(self, tempdir):
        database = self.create_database(tempdir)
        self.assertRaises(KeyError, lambda: database[self.key1])

    @with_tempdir
    def test_can_overwrite_key(self, tempdir):
        database = self.create_database(tempdir)

        database[self.key1] = self.value1
        database[self.key2] = self.value2
        self.assertEqual(database[self.key1], self.value1)
        self.assertEqual(database[self.key2], self.value2)

        database[self.key1] = self.value2
        self.assertEqual(database[self.key1], self.value2)
        self.assertEqual(database[self.key2], self.value2)

        database[self.key2] = self.value1
        self.assertEqual(database[self.key1], self.value2)
        self.assertEqual(database[self.key2], self.value1)


class TestPickedDataBase(TestDataBase):
    """
    Test the picked database

    Re-uses test from TestDataBase class
    """

    value1 = (1, "foo", set([1, 2, 3]))
    value2 = (3, 4, 5, ("foo", "bar"))

    @staticmethod
    def create_database(tempdir, new=False):
        return PickledDataBase(TestDataBase.create_database(tempdir, new))
