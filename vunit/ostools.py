# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides operating systems dependent functionality that can be easily
stubbed for testing
"""


from __future__ import print_function

import time
import subprocess
import threading
import shutil
try:
    # Python 3.x
    from queue import Queue, Empty
except ImportError:
    # Python 2.7
    from Queue import Queue, Empty  # pylint: disable=import-error

from os.path import exists, getmtime, dirname, relpath, splitdrive
import os
import io

import logging
LOGGER = logging.getLogger(__name__)

IS_WINDOWS_SYSTEM = os.name == 'nt'


class ProgramStatus(object):
    """
    Maintain global program status to support graceful shutdown
    """
    def __init__(self):
        self._lock = threading.Lock()
        self._shutting_down = False

    @property
    def is_shutting_down(self):
        with self._lock:
            return self._shutting_down

    def check_for_shutdown(self):
        if self.is_shutting_down:
            raise KeyboardInterrupt

    def shutdown(self):
        with self._lock:
            self._shutting_down = True

PROGRAM_STATUS = ProgramStatus()


class InterruptableQueue(object):
    """
    A Queue which can be interrupted
    """

    def __init__(self):
        self._queue = Queue()

    def get(self):
        while True:
            PROGRAM_STATUS.check_for_shutdown()
            try:
                return self._queue.get(timeout=0.1)
            except Empty:
                pass

    def put(self, value):
        self._queue.put(value)

    def empty(self):
        return self._queue.empty()


class Process(object):
    """
    A simple process interface which supports asynchronously consuming the stdout and stderr
    of the process while it is running.
    """

    class NonZeroExitCode(Exception):
        pass

    def __init__(self, args, cwd=None):
        self._args = args

        # Create process with new process group
        # Sending a signal to a process group will send it to all children
        # Hopefully this way no orphaned processes will be left behind
        if IS_WINDOWS_SYSTEM:  # Windows
            self._process = subprocess.Popen(
                args,
                bufsize=0,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stdin=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                # Create new process group on Windows
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        else:
            self._process = subprocess.Popen(
                args,
                bufsize=0,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stdin=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                # Create new process group on POSIX, setpgrp does not exist on Windows
                preexec_fn=os.setpgrp)  # pylint: disable=no-member

        LOGGER.debug("Started process with pid=%i: '%s'", self._process.pid, (" ".join(args)))

        self._queue = InterruptableQueue()
        self._reader = AsynchronousFileReader(change_encoding(self._process.stdout), self._queue)
        self._reader.start()

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

        retcode = self.wait()
        return retcode

    def wait(self):
        """
        Wait while without completely blocking to avoid
        deadlock when shutting down
        """
        while self._process.poll() is None:
            PROGRAM_STATUS.check_for_shutdown()
            time.sleep(0.05)
            LOGGER.debug("Waiting for process with pid=%i to stop", self._process.pid)
        return self._process.returncode

    def is_alive(self):
        """
        Returns true if alive
        """
        return self._process.poll() is None

    def consume_output(self, callback=print):
        """
        Consume the output of the process
        @param callback Called for each line of output
        @raises Process.NonZeroExitCode when the process does not exit with code zero
        """

        try:
            if callback is not None:
                while not self._reader.eof():
                    line = self._queue.get()
                    if line is None:
                        break

                    if callback(line) is not None:
                        return
            else:
                while (not self._reader.eof()) and (self._queue.get() is not None):
                    pass

            retcode = None
            while retcode is None:
                retcode = self.wait()
                if retcode != 0:
                    raise Process.NonZeroExitCode

        except:
            self.terminate()
            raise
        self.terminate()

    def terminate(self):
        """
        Terminate the process
        """
        # Let's be tidy and join the threads we've started.
        if self._process.poll() is None:
            LOGGER.debug("Terminating process with pid=%i", self._process.pid)
            self._process.terminate()

        if self._process.poll() is None:
            time.sleep(0.05)

        if self._process.poll() is None:
            LOGGER.debug("Killing process with pid=%i", self._process.pid)
            self._process.kill()

        if self._process.poll() is None:
            LOGGER.debug("Waiting for process with pid=%i", self._process.pid)
            self.wait()

        LOGGER.debug("Process with pid=%i terminated with code=%i",
                     self._process.pid,
                     self._process.returncode)

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
            if PROGRAM_STATUS.is_shutting_down:
                break
            self._queue.put(line[:-1])
        self._queue.put(None)

    def eof(self):
        """Check whether there is no more content to expect."""
        return not self.is_alive() and self._queue.empty()


def read_file(file_name):
    """ To stub during testing """
    with io.open(file_name, "r", encoding="latin_1") as file_to_read:
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


def renew_path(path):
    """
    Ensure path directory exists and is empty

    On Windows deleting a file will not actually delete it right away but only
    mark it for deletion. Therefore there is a race-condition between rmtree and makedirs.
    Virus scanners and file system indexers might temporarily block a file from being deleted right away

    http://stackoverflow.com/questions/27625683/can-anyone-explain-this-weird-behaviour-of-shutil-rmtree-and-shutil-copytree
    """
    if IS_WINDOWS_SYSTEM:
        retries = 10
        while retries > 0 and exists(path):
            shutil.rmtree(path, ignore_errors=retries > 1)
            time.sleep(0.01)
            retries -= 1
    else:
        if exists(path):
            shutil.rmtree(path)
    os.makedirs(path)


def change_encoding(textio):
    """
    If Python 3 change encoding of TextIOWrapper to latin-1 ignoring decode errors
    """
    if isinstance(textio, io.TextIOWrapper):
        # Python 3
        return io.TextIOWrapper(textio.buffer, encoding='latin-1', errors="ignore")
    else:
        return textio


def simplify_path(path):
    """
    Return relative path towards current working directory
    unless it is a separate Windows drive
    """
    cwd = os.getcwd()
    drive_cwd = splitdrive(cwd)[0]
    drive_path = splitdrive(path)[0]
    if drive_path == drive_cwd:
        return relpath(path, cwd)
    else:
        return path
