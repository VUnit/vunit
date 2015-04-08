# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides operating systems dependent functionality that can be easily
stubbed for testing
"""


from __future__ import print_function

import time
import subprocess
import threading
try:
    # Python 3.x
    from queue import Queue
except ImportError:
    # Python 2.7
    from Queue import Queue

from os.path import exists, getmtime, dirname
import os

import logging
LOGGER = logging.getLogger(__name__)


class Process:
    """
    A simple process interface which supports asynchronously consuming the stdout and stderr
    of the process while it is running.
    """

    class NonZeroExitCode(Exception):
        pass

    def __init__(self, args, cwd=None):
        LOGGER.debug("Starting process: '%s'", (" ".join(args)))
        self._process = subprocess.Popen(
            args,
            bufsize=0,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stdin=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True)

        self._queue = Queue()
        self._reader = AsynchronousFileReader(self._process.stdout, self._queue)
        self._reader.start()
        self.output = ""

    def write(self, *args, **kwargs):
        """ Write to stdin """
        if not self._process.stdin.closed:
            self._process.stdin.write(*args, **kwargs)

    def next_line(self):
        """
        Return either the next line or the exit code
        """

        if not self._reader.eof():
            # Show what we received from standard output.
            msg = self._queue.get()

            if msg is not None:
                return msg

        retcode = self._process.wait()
        return retcode

    def consume_output(self, callback=print):
        """
        Consume the output of the process
        @param callback Called for each line of output
        @raises Process.NonZeroExitCode when the process does not exit with code zero
        """

        try:
            while True:
                line = self.next_line()
                if isinstance(line, int):
                    if line != 0:
                        raise Process.NonZeroExitCode
                    else:
                        break
                else:
                    self.output += line + "\n"
                    if callback:
                        if callback(line) is not None:
                            return
        except:
            self.terminate()
            raise
        self.terminate()

    def terminate(self):
        """
        Terminate the process
        """
        # Let's be tidy and join the threads we've started.
        if self._process.returncode is None:
            self._process.terminate()
        self._reader.join()
        self._process.stdout.close()
        self._process.stdin.close()

    def __del__(self):
        self.terminate()


class AsynchronousFileReader(threading.Thread):
    """
    Helper class to implement asynchronous reading of a file
    in a separate thread. Pushes read lines on a queue to
    be consumed in another thread.
    """

    def __init__(self, fd, queue):
        threading.Thread.__init__(self)
        self._fd = fd
        self._queue = queue

    def run(self):
        """The body of the tread: read lines and put them on the queue."""
        for line in iter(self._fd.readline, ''):
            self._queue.put(line[:-1])
        self._queue.put(None)

    def eof(self):
        """Check whether there is no more content to expect."""
        return not self.is_alive() and self._queue.empty()


def read_file(file_name):
    """ To stub during testing """
    with open(file_name, "r") as file_to_read:
        data = file_to_read.read()
    return data


def write_file(file_name, contents):
    """ To stub during testing """

    path = dirname(file_name)
    if path == "":
        path = "."

    if not file_exists(path):
        os.makedirs(path)

    with open(file_name, "w") as file_to_write:
        file_to_write.write(contents)


def file_exists(file_name):
    """ To stub during testing """
    return exists(file_name)


def get_modification_time(file_name):
    """ To stub during testing """
    return getmtime(file_name)


def get_time():
    """ To stub during testing """
    return time.time()
