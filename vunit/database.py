# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
A simple file based database
"""

from pathlib import Path
import os
import pickle
import io
import struct
from vunit.ostools import renew_path


class DataBase(object):
    """
    A simple file based database
    both keys and values are bytes

    The database consists of a folder with files called nodes.
    Each nodes contains four bytes denoting the key length as an
    unsigned integer followed by the key followed by the data.

    The reason to not just have the keys as the file names is that
    many operating systems does not support very long file names thus limiting the key length
    """

    def __init__(self, path, new=False):
        """
        Create database in path
        - path is a directory
        - new create new database
        """
        self._path = path

        if new:
            renew_path(path)
        elif not Path(path).exists():
            os.makedirs(path)

        # Map keys to nodes indexes
        self._keys_to_nodes = self._discover_nodes()
        if not self._keys_to_nodes:
            self._next_node = 0
        else:
            self._next_node = max(self._keys_to_nodes.values()) + 1

    def _discover_nodes(self):
        """
        Discover nodes already found in the database
        """
        keys_to_nodes = {}
        for file_base_name in os.listdir(self._path):
            key = self._read_key(str(Path(self._path) / file_base_name))
            assert key not in keys_to_nodes  # Two nodes contains the same key
            keys_to_nodes[key] = int(file_base_name)
        return keys_to_nodes

    @staticmethod
    def _read_key_from_fptr(fptr):
        """
        Read the key from a file pointer
        first read four bytes for the key length then read the key
        """
        key_size = struct.unpack("I", fptr.read(4))[0]
        key = fptr.read(key_size)
        return key

    def _read_key(self, file_name):
        """
        Read key found in file_name
        """
        with io.open(file_name, "rb") as fptr:
            return self._read_key_from_fptr(fptr)

    def _read_data(self, file_name):
        """
        Read key found in file_name
        """
        with io.open(file_name, "rb") as fptr:
            self._read_key_from_fptr(fptr)
            data = fptr.read()
        return data

    @staticmethod
    def _write_node(file_name, key, value):
        """
        Write node to file
        """
        with io.open(file_name, "wb") as fptr:
            fptr.write(struct.pack("I", len(key)))
            fptr.write(key)
            fptr.write(value)

    def _to_file_name(self, key):
        """
        Convert key to file name
        """
        return str(Path(self._path) / str(self._keys_to_nodes[key]))

    def _allocate_node_for_key(self, key):
        """
        Allocate a node index for a new key
        """
        assert key not in self._keys_to_nodes
        self._keys_to_nodes[key] = self._next_node
        self._next_node += 1

    def __setitem__(self, key, value):
        if key not in self._keys_to_nodes:
            self._allocate_node_for_key(key)
        self._write_node(self._to_file_name(key), key, value)

    def __getitem__(self, key):
        if key not in self:
            raise KeyError(key)

        return self._read_data(self._to_file_name(key))

    def __contains__(self, key):
        return key in self._keys_to_nodes


class PickledDataBase(object):
    """
    Wraps a byte based database (un)pickling the values
    Allowing storage of arbitrary Python objects
    """

    def __init__(self, database):
        self._database = database

    def __getitem__(self, key):
        return pickle.loads(self._database[key])

    def __setitem__(self, key, value):
        self._database[key] = pickle.dumps(value, protocol=pickle.HIGHEST_PROTOCOL)

    def __contains__(self, key):
        return key in self._database
