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
        latest_dependency_updates=None,
        test_history=None,
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
        self._latest_dependency_updates = {} if latest_dependency_updates is None else latest_dependency_updates
        self._test_history = {} if test_history is None else test_history

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

        scheduler = TestScheduler(test_suites, self._num_threads, self._latest_dependency_updates, self._test_history)

        threads = []

        # Disable continuous output in parallel mode
        write_stdout = self._is_verbose and self._num_threads == 1

        try:
            sys.stdout = ThreadLocalOutput(self._local, self._stdout)
            sys.stderr = ThreadLocalOutput(self._local, self._stdout)

            # Start P-1 worker threads
            for thread_id in range(1, self._num_threads):
                new_thread = threading.Thread(
                    target=self._run_thread,
                    args=(write_stdout, scheduler, num_tests),
                    kwargs={"is_main": False, "thread_id": thread_id},
                )
                threads.append(new_thread)
                new_thread.start()

            # Run one worker in main thread such that P=1 is not multithreaded
            self._run_thread(write_stdout, scheduler, num_tests, is_main=True, thread_id=0)

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

    def _run_thread(self, write_stdout, scheduler, num_tests, *, is_main, thread_id):
        """
        Run worker thread
        """
        self._local.output = self._stdout

        while True:
            test_suite = None
            try:
                test_suite = scheduler.next(thread_id)

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
                    scheduler.test_done(thread_id)

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
        seed = test_suite.get_seed()

        for test_name in test_suite.test_names:
            status = results[test_name]
            self._report.add_result(
                test_name,
                status,
                time_per_test,
                output_file_name,
                test_suite_name=test_suite.name,
                start_time=start_time,
                seed=seed,
            )
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


class TestScheduler(object):  # pylint: disable=too-many-instance-attributes
    """
    Schedule tests to different treads
    """

    def _create_test_suite_sets(self, test_suites):
        """
        Create static priority based on test result and file change history.
        """
        # Test suites are divided into sets which are executed in order. The internal order within a set
        # is decided dynamically at run-time.
        #
        # The 5 sets contains:
        #
        # 0. Test suites that failed before and for which no updates have been made. Expected to fail again.
        # 1. Test suites that failed before but updates have been made that can change that.
        # 2. Test suites without a history. New tests are more likely to fail and should be executed early.
        # 3. Test suites that passed before but depends on updates. There is a risk that we've introduced new bugs.
        # 4. Test suites that passed before and for which there are no updates. They are expected to pass again.
        #
        # Within sets, test suites are sorted in execution time order starting with the fastest test.
        # This is in preparation for the dynamic scheduling that decides the final order within a set.
        # The exception is set 2 which has no history of execution time.

        # A test suite set keeps the sorted test suite list as well as the total estimated execution time (if available)
        # for the test suites within the list.
        test_suite_sets = [{"test_suites": [], "total_exec_time": 0 if idx != 2 else None} for idx in range(5)]

        for test_suite in test_suites:
            test_suite_data = self._test_history.get(test_suite.name, None)
            if not test_suite_data:
                test_suite_sets[2]["test_suites"].append({"test_suite": test_suite, "exec_time": None})
            else:
                # Test suites with multiple tests are placed in the set where the highest priority test belongs
                highest_priority_set = None
                exec_time = 0
                for test_name in test_suite.test_names:
                    test_data = test_suite_data.get(test_name, False)
                    set_idx = 2  # Default set for new test suites

                    if test_data:
                        if test_data["total_time"] is not None:
                            exec_time += test_data["total_time"]
                        updated_dependency = self._latest_dependency_updates[test_suite.file_name] > test_data.get(
                            "start_time", 0
                        )

                        if test_data["skipped"]:
                            set_idx = 2
                        elif test_data["failed"]:
                            set_idx = 1 if updated_dependency else 0
                        else:
                            set_idx = 3 if updated_dependency else 4

                    highest_priority_set = (
                        min(highest_priority_set, set_idx) if highest_priority_set is not None else set_idx
                    )

                test_suite_sets[highest_priority_set]["test_suites"].append(
                    {"test_suite": test_suite, "exec_time": exec_time}
                )
                if highest_priority_set != 2:
                    test_suite_sets[highest_priority_set]["total_exec_time"] += exec_time

        for set_idx, test_suite_set in enumerate(test_suite_sets):
            if set_idx == 2:
                continue
            test_suite_set["test_suites"].sort(key=lambda item: item["exec_time"])

        return test_suite_sets

    def __init__(self, test_suites, num_threads, latest_dependency_updates, test_history):
        self._num_threads = num_threads
        self._latest_dependency_updates = latest_dependency_updates
        self._test_history = test_history
        self._test_suite_sets = self._create_test_suite_sets(test_suites)
        self._lock = threading.Lock()
        self._num_tests = sum(len(test_suite_set["test_suites"]) for test_suite_set in self._test_suite_sets)
        self._num_done = 0
        self._thread_status = [{"start_time": None, "exec_time": None} for _ in range(num_threads)]

        # Estimate remaing test time
        self._exec_time_for_remaining_tests = sum(
            test_suite_set["total_exec_time"]
            for test_suite_set in self._test_suite_sets
            if test_suite_set["total_exec_time"]
        )

    def next(self, thread_id):
        """
        Return the next test
        """
        ostools.PROGRAM_STATUS.check_for_shutdown()
        with self._lock:  # pylint: disable=not-context-manager
            # Get the first non-empty test suite set or raise StopIteration
            test_suite_set = next((tss for tss in self._test_suite_sets if tss["test_suites"]))

            # Estimate remaining execution time for threads
            now = time.time()
            remaining_exec_time_for_threads = []
            for idx, status in enumerate(self._thread_status):
                if (idx == thread_id) or not (status["start_time"] and status["exec_time"]):
                    remaining_exec_time_for_threads.append(0)
                else:
                    remaining_exec_time_for_threads.append(max(0, status["start_time"] + status["exec_time"] - now))

            # Estimate time to completion for all threads assuming perfect load-balancing
            time_to_completion = (
                sum(remaining_exec_time_for_threads) + self._exec_time_for_remaining_tests
            ) / self._num_threads

            # Assuming the shortest test is picked, when is the next thread available
            test_suites = test_suite_set["test_suites"]
            remaining_exec_time_for_threads[thread_id] = (
                test_suites[0]["exec_time"] if test_suites[0]["exec_time"] is not None else 0
            )
            time_to_next_thread_completion = (
                min(remaining_exec_time_for_threads) if remaining_exec_time_for_threads else None
            )

            # Select the longest test if delaying it would risk exceeding the ideal time to completion.
            longest_test_exec_time = test_suites[-1]["exec_time"]

            if (longest_test_exec_time is not None) and (
                (time_to_completion <= longest_test_exec_time)
                or (
                    (time_to_next_thread_completion is not None)
                    and (time_to_completion - time_to_next_thread_completion < longest_test_exec_time)
                )
            ):
                test_suite_data = test_suites.pop(-1)  # Pick the longest test
            else:
                test_suite_data = test_suites.pop(0)  # Pick the fastest test

            # Update execution tracking
            exec_time = test_suite_data["exec_time"]
            if exec_time:
                self._exec_time_for_remaining_tests -= exec_time
            self._thread_status[thread_id].update(exec_time=exec_time, start_time=now)

            return test_suite_data["test_suite"]

    def test_done(self, thread_id):
        """
        Signal that a test has been done
        """
        with self._lock:  # pylint: disable=not-context-manager
            self._thread_status[thread_id]["start_time"] = None
            self._thread_status[thread_id]["exec_time"] = None
            self._num_done += 1

    def is_finished(self):
        with self._lock:  # pylint: disable=not-context-manager
            return self._num_done >= self._num_tests

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
