# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Utility to perform costly operation on file contents which can be cached
"""

import os
from vunit.hashing import hash_string
from vunit.ostools import read_file


def cached(key, function, file_name, encoding, *, database=None, newline=None):
    """
    Call function with file content if an update is needed
    """

    if database is None:
        # Without a database just return the function of the contents
        content = read_file(file_name, encoding=encoding, newline=newline)
        return function(content)

    function_key = f"{key!s}({file_name!s}, newline={newline!s})".encode()
    content, content_hash = _file_content_hash(file_name, encoding, database, newline=newline)

    if function_key not in database:
        # We do not have a cached version of this computation
        # recompute and update database
        if content is None:
            content = read_file(file_name, encoding=encoding, newline=newline)
        result = function(content)
        database[function_key] = content_hash, result
        return result

    old_content_hash, old_result = database[function_key]
    if old_content_hash == content_hash:
        return old_result

    # Content hash differs, recompute and update database
    if content is None:
        content = read_file(file_name, encoding=encoding, newline=newline)
    result = function(content)
    database[function_key] = content_hash, result
    return result


def file_content_hash(file_name, encoding, database=None):
    """
    Returns the hash of the contents of the file

    Use the database to keep a persistent cache of the last content
    hash.
    """
    _, content_hash = _file_content_hash(file_name, encoding, database)
    return content_hash


def _file_content_hash(file_name, encoding, database=None, newline=None):
    """
    Returns the file content as well as the hash of the content

    Use the database to keep a persistent cache of the last content
    hash.  If the file modification date has not changed assume the
    hash is the same and do not re-open the file.
    """

    if database is None:
        content = read_file(file_name, encoding=encoding, newline=newline)
        return content, hash_string(content)

    key = f"cached._file_content_hash({file_name!s}, newline={newline!s})".encode()

    if key not in database:
        content = read_file(file_name, encoding=encoding, newline=newline)
        content_hash = hash_string(content)
        timestamp = os.path.getmtime(file_name)
        database[key] = timestamp, content_hash
        return content, content_hash

    timestamp = os.path.getmtime(file_name)
    last_timestamp, last_content_hash = database[key]
    if timestamp != last_timestamp:
        content = read_file(file_name, encoding=encoding, newline=newline)
        content_hash = hash_string(content)
        database[key] = timestamp, content_hash
        return content, content_hash

    return None, last_content_hash
