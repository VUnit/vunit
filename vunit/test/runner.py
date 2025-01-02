# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Provided functionality to run a suite of test in a robust way
"""

import os
from multiprocessing import cpu_count
from pathlib import Path
import traceback
import threading
import sys
import time
import logging
import string
from datetime import datetime
from contextlib import contextmanager
from .. import ostools
from ..hashing import hash_string
from .report import PASSED, FAILED, SKIPPED

LOGGER = logging.getLogger(__name__)


class TestRunner(object):  # pylint: disable=too-many-instance-attributes
    """
    Administer the execution of a list of test suites
    """

    VERBOSITY_QUIET = 0
    VERBOSITY_NORMAL = 1
    VERBOSITY_VERBOSE = 2

    def __init__(  # pylint: disable=too-many-arguments
        self,
        report,
        output_path,
        *,
        verbosity=VERBOSITY_NORMAL,
        num_threads=1,
        fail_fast=False,
        dont_catch_exceptions=False,
        no_color=False,
    ):
        self._lock = threading.Lock()
        self._fail_fast = fail_fast
        self._abort = False
        self._local = threading.local()
        self._report = report
        self._output_path = output_path
        assert verbosity in (
            self.VERBOSITY_QUIET,
            self.VERBOSITY_NORMAL,
            self.VERBOSITY_VERBOSE,
        )
        self._verbosity = verbosity
        self._num_threads = num_threads or cpu_count()
        self._stdout = sys.stdout
        self._stdout_ansi = wrap(self._stdout, use_color=not no_color)
        self._stderr = sys.stderr
        self._dont_catch_exceptions = dont_catch_exceptions
        self._no_color = no_color

        ostools.PROGRAM_STATUS.reset()

    @property
    def _is_verbose(self):
        return self._verbosity == self.VERBOSITY_VERBOSE

    @property
    def _is_quiet(self):
        return self._verbosity == self.VERBOSITY_QUIET

    def run(self, test_suites):
        """
        Run a list of test suites
        """

        if not Path(self._output_path).exists():
            os.makedirs(self._output_path)

        self._create_test_mapping_file(test_suites)

        num_tests = 0
        for test_suite in test_suites:
            for test_name in test_suite.test_names:
                num_tests += 1
                if self._is_verbose:
                    print("Running test: " + test_name)

        if self._is_verbose:
            print(f"Running {num_tests:d} tests")
            print()

        self._report.set_expected_num_tests(num_tests)

        scheduler = TestScheduler(test_suites)

        threads = []

        # Disable continuous output in parallel mode
        write_stdout = self._is_verbose and self._num_threads == 1

        try:
            sys.stdout = ThreadLocalOutput(self._local, self._stdout)
            sys.stderr = ThreadLocalOutput(self._local, self._stdout)

            # Start P-1 worker threads
            for _ in range(self._num_threads - 1):
                new_thread = threading.Thread(
                    target=self._run_thread,
                    args=(write_stdout, scheduler, num_tests, False),
                )
                threads.append(new_thread)
                new_thread.start()

            # Run one worker in main thread such that P=1 is not multithreaded
            self._run_thread(write_stdout, scheduler, num_tests, True)

            scheduler.wait_for_finish()

        except KeyboardInterrupt:
            LOGGER.debug("TestRunner: Caught Ctrl-C shutting down")
            ostools.PROGRAM_STATUS.shutdown()
            raise

        finally:
            for thread in threads:
                thread.join()

            sys.stdout = self._stdout
            sys.stderr = self._stderr
            LOGGER.debug("TestRunner: Leaving")

    def _run_thread(self, write_stdout, scheduler, num_tests, is_main):
        """
        Run worker thread
        """
        self._local.output = self._stdout

        while True:
            test_suite = None
            try:
                test_suite = scheduler.next()

                output_path = self._get_output_path(test_suite.name)
                output_file_name = str(Path(output_path) / "output.txt")

                with self._stdout_lock():
                    for test_name in test_suite.test_names:
                        now = datetime.now().strftime("%H:%M:%S")
                        print(f"({now}) Starting {test_name!s}")
                    print(f"Output file: {output_file_name!s}")

                self._run_test_suite(test_suite, write_stdout, num_tests, output_path, output_file_name)

            except StopIteration:
                return

            except KeyboardInterrupt:
                # Only main thread should handle KeyboardInterrupt
                if is_main:
                    LOGGER.debug("MainWorkerThread: Caught Ctrl-C shutting down")
                    raise

                return

            finally:
                if test_suite is not None:
                    scheduler.test_done()

    def _get_output_path(self, test_suite_name):
        """
        Construct the full output path of a test case.
        Ensure no bad characters and no long path names.
        """
        output_path = str(Path(self._output_path).resolve())
        safe_name = "".join(char if _is_legal(char) else "_" for char in test_suite_name) + "_"
        hash_name = hash_string(test_suite_name)

        if "VUNIT_SHORT_TEST_OUTPUT_PATHS" in os.environ:
            full_name = hash_name
        elif sys.platform == "win32":
            max_path = 260
            margin = int(os.environ.get("VUNIT_TEST_OUTPUT_PATH_MARGIN", "100"))
            prefix_len = len(output_path)
            full_name = safe_name[: min(max_path - margin - prefix_len - len(hash_name), len(safe_name))] + hash_name
        else:
            full_name = safe_name + hash_name

        return str(Path(output_path) / full_name)

    def _add_skipped_tests(
        self, test_suite, results, start_time, num_tests, output_file_name
    ):  # pylint: disable=too-many-positional-arguments
        """
        Add skipped tests
        """
        for name in test_suite.test_names:
            results[name] = SKIPPED
        self._add_results(test_suite, results, start_time, num_tests, output_file_name)

    def _run_test_suite(  # pylint: disable=too-many-locals
        self, test_suite, write_stdout, num_tests, output_path, output_file_name
    ):  # pylint: disable=too-many-positional-arguments
        """
        Run the actual test suite
        """
        color_output_file_name = str(Path(output_path) / "output_with_color.txt")

        output_file = None
        color_output_file = None

        start_time = ostools.get_time()
        results = self._fail_suite(test_suite)

        try:
            self._prepare_test_suite_output_path(output_path)
            output_file = wrap(
                Path(output_file_name).open("a+", encoding="utf-8"),  # pylint: disable=consider-using-with
                use_color=False,
            )
            output_file.seek(0)
            output_file.truncate()

            if write_stdout:
                output_from = self._stdout_ansi
            else:
                color_output_file = Path(color_output_file_name).open(  # pylint: disable=consider-using-with
                    "w", encoding="utf-8"
                )
                output_from = color_output_file
            self._local.output = Tee([output_from, output_file])

            def read_output():
                """
                Called to read the contents of the output file on demand
                """
                output_file.flush()
                prev = output_file.tell()
                output_file.seek(0)
                contents = output_file.read()
                output_file.seek(prev)
                return contents

            results = test_suite.run(output_path=output_path, read_output=read_output)
        except KeyboardInterrupt as exk:
            self._add_skipped_tests(test_suite, results, start_time, num_tests, output_file_name)
            raise KeyboardInterrupt from exk
        except:  # pylint: disable=bare-except
            if self._dont_catch_exceptions:
                raise

            with self._stdout_lock():
                traceback.print_exc()
        finally:
            self._local.output = self._stdout

            for fptr in (ptr for ptr in [output_file, color_output_file] if ptr is not None):
                fptr.flush()
                fptr.close()

        any_not_passed = any(value != PASSED for value in results.values())

        with self._stdout_lock():
            if (color_output_file is not None) and (any_not_passed or self._is_verbose) and not self._is_quiet:
                self._print_output(color_output_file_name)

            self._add_results(test_suite, results, start_time, num_tests, output_file_name)

            if self._fail_fast and any_not_passed:
                self._abort = True

    @staticmethod
    def _prepare_test_suite_output_path(output_path):
        """
        Make sure the directory exists and is empty before running test.
        """
        ostools.renew_path(output_path)

    def _create_test_mapping_file(self, test_suites):
        """
        Create a file mapping test name to test output folder.
        This is to allow the user to find the test output folder when it is hashed
        """
        mapping_file_name = Path(self._output_path) / "test_name_to_path_mapping.txt"

        # Load old mapping to remember non-deleted test folders as well
        # even when re-running only a single test case
        if mapping_file_name.exists():
            with mapping_file_name.open("r", encoding="utf-8") as fptr:
                mapping = set(fptr.read().splitlines())
        else:
            mapping = set()

        for test_suite in test_suites:
            test_output = self._get_output_path(test_suite.name)
            mapping.add(f"{Path(test_output).name!s} {test_suite.name!s}")

        # Sort by everything except hash
        mapping = sorted(mapping, key=lambda value: value[value.index(" ") :])

        with mapping_file_name.open("w", encoding="utf-8") as fptr:
            for value in mapping:
                fptr.write(value + "\n")

    def _print_output(self, output_file_name):
        """
        Print contents of output file if it exists
        """
        with Path(output_file_name).open("r", encoding="utf-8") as fread:
            for line in fread.readlines():
                self._stdout_ansi.write(line)

    def _add_results(
        self, test_suite, results, start_time, num_tests, output_file_name
    ):  # pylint: disable=too-many-positional-arguments
        """
        Add results to test report
        """
        runtime = ostools.get_time() - start_time
        time_per_test = runtime / len(results)

        for test_name in test_suite.test_names:
            status = results[test_name]
            self._report.add_result(test_name, status, time_per_test, output_file_name)
            self._report.print_latest_status(total_tests=num_tests)
        print()

    @staticmethod
    def _fail_suite(test_suite):
        """Return failure for all tests in suite"""
        results = {}
        for test_name in test_suite.test_names:
            results[test_name] = FAILED
        return results

    @contextmanager
    def _stdout_lock(self):
        """
        Enter this lock when printing to stdout
        Ensures no additional output is printed during abort
        """
        with self._lock:  # pylint: disable=not-context-manager
            if self._abort:
                raise KeyboardInterrupt
            yield


class Tee(object):
    """
    Provide a write method which writes to multiple files
    like the unix 'tee' command.
    """

    def __init__(self, files):
        self._files = files

    def write(self, txt):
        for ofile in self._files:
            ofile.write(txt)

    def flush(self):
        for ofile in self._files:
            ofile.flush()


class ThreadLocalOutput(object):
    """
    Replacement for stdout/err that separates re-directs
    output to a thread local file interface
    """

    def __init__(self, local, stdout):
        self._local = local
        self._stdout = stdout

    def write(self, txt):
        """
        Write to file object
        """
        if hasattr(self._local, "output"):
            self._local.output.write(txt)
        else:
            self._stdout.write(txt)

    def flush(self):
        """
        Flush file object
        """
        if hasattr(self._local, "output"):
            self._local.output.flush()
        else:
            self._stdout.flush()


class TestScheduler(object):
    """
    Schedule tests to different treads
    """

    def __init__(self, tests):
        self._lock = threading.Lock()
        self._tests = tests
        self._idx = 0
        self._num_done = 0

    def next(self):
        """
        Return the next test
        """
        ostools.PROGRAM_STATUS.check_for_shutdown()
        with self._lock:  # pylint: disable=not-context-manager
            if self._idx < len(self._tests):
                idx = self._idx
                self._idx += 1
                return self._tests[idx]

            raise StopIteration

    def test_done(self):
        """
        Signal that a test has been done
        """
        with self._lock:  # pylint: disable=not-context-manager
            self._num_done += 1

    def is_finished(self):
        with self._lock:  # pylint: disable=not-context-manager
            return self._num_done >= len(self._tests)

    def wait_for_finish(self):
        """
        Block until all tests have been done
        """
        while not self.is_finished():
            time.sleep(0.05)


LEGAL_CHARS = string.printable
ILLEGAL_CHARS = ' <>"|:*%?\\/#&;()'


def _is_legal(char):
    """
    Return true if the character is legal to have in a file name
    """
    return (char in LEGAL_CHARS) and (char not in ILLEGAL_CHARS)


def wrap(file_obj, use_color=True):
    """
    Wrap file_obj in another stream which handles ANSI color codes using colorama

    NOTE:
    imports colorama here to avoid dependency from setup.py importing VUnit before colorama is installed
    """
    from colorama import (  # type: ignore # pylint: disable=import-outside-toplevel
        AnsiToWin32,
    )

    if use_color:
        return AnsiToWin32(file_obj).stream

    return AnsiToWin32(file_obj, strip=True, convert=False).stream
