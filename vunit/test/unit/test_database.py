# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the database related classes
"""

import unittest
from os.path import join, dirname
from vunit.database import DataBase, PickledDataBase
from vunit.ostools import renew_path


class TestDataBase(unittest.TestCase):
    """
    The the byte based database
    """

    key1 = b"key2"
    key2 = b"key1"
    value1 = b"value1"
    value2 = b"value2"

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_database_out")
        renew_path(self.output_path)

    def create_database(self, new=False):
        return DataBase(join(self.output_path, "database"), new=new)

    def test_add_items(self):
        database = self.create_database()

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

    def test_is_persistent(self):
        self.test_add_items()
        database = self.create_database()
        self.assertEqual(database[self.key1], self.value1)
        self.assertEqual(database[self.key2], self.value2)

    def test_new_database_is_created(self):
        self.test_add_items()
        database = self.create_database(new=True)
        self.assertTrue(self.key1 not in database)
        self.assertTrue(self.key2 not in database)

    def test_missing_key_raises_keyerror(self):
        database = self.create_database()
        self.assertRaises(KeyError, lambda: database[self.key1])

    def test_can_overwrite_key(self):
        database = self.create_database()

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

    def create_database(self, new=False):
        return PickledDataBase(TestDataBase.create_database(self, new))
