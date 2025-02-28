# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test scheduler
"""

import unittest
from unittest import mock
from vunit.test.runner import TestScheduler


class TestTestScheduler(unittest.TestCase):
    """
    Test the test scheduler
    """

    def setUp(self):
        self._test_history = dict()

    @staticmethod
    def _create_test_suite(name, test_names, file_name):
        """Helper method to create a mock test suite."""

        test_suite = mock.MagicMock()
        test_suite.name = name
        test_suite.test_names = test_names
        test_suite.file_name = file_name
        return test_suite

    def _add_test_history(self, test_suite_name, test_name, status, start_time, total_time):
        """Helper method to create test suite histories."""

        if test_suite_name not in self._test_history:
            self._test_history[test_suite_name] = dict()

        history = dict()
        history["total_time"] = total_time
        history["passed"] = status == "passed"
        history["skipped"] = status == "skipped"
        history["failed"] = status == "failed"
        history["start_time"] = start_time
        self._test_history[test_suite_name][test_name] = history

    def test_that_new_test_suites_go_to_set_2(self):
        latest_dependency_updates = {}
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test2", "lib1.tb1.test2", "passed", 0, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 2:
                self.assertIsNone(result[set_idx]["total_exec_time"])
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
                self.assertIsNone(result[set_idx]["test_suites"][0]["exec_time"])
            else:
                self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_skipped_test_suites_go_to_set_2(self):
        latest_dependency_updates = dict(file1=0)
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test1", "lib1.tb1.test1", "skipped", 0, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 2:
                self.assertIsNone(result[set_idx]["total_exec_time"])
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
            else:
                self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_failed_test_suites_wo_updates_go_to_set_0(self):
        latest_dependency_updates = dict(file1=0)
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test1", "lib1.tb1.test1", "failed", 1, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 0:
                self.assertEqual(result[set_idx]["total_exec_time"], 10)
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_failed_test_suites_w_updates_go_to_set_1(self):
        latest_dependency_updates = dict(file1=2)
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test1", "lib1.tb1.test1", "failed", 1, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 1:
                self.assertEqual(result[set_idx]["total_exec_time"], 10)
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_passed_test_suites_wo_updates_go_to_set_4(self):
        latest_dependency_updates = dict(file1=0)
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test1", "lib1.tb1.test1", "passed", 1, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 4:
                self.assertEqual(result[set_idx]["total_exec_time"], 10)
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_passed_test_suites_w_updates_go_to_set_3(self):
        latest_dependency_updates = dict(file1=2)
        test_suites = [self._create_test_suite("lib1.tb1.test1", ["lib1.tb1.test1"], "file1")]
        self._add_test_history("lib1.tb1.test1", "lib1.tb1.test1", "passed", 1, 10)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 3:
                self.assertEqual(result[set_idx]["total_exec_time"], 10)
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1.test1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_highest_priority_set_wins(self):
        latest_dependency_updates = dict(file1=2)
        test_suites = [
            self._create_test_suite(
                "lib1.tb1",
                ["lib1.tb1.test1", "lib1.tb1.test2", "lib1.tb1.test3", "lib1.tb1.test4", "lib1.tb1.test5"],
                "file1",
            )
        ]
        self._add_test_history("lib1.tb1", "lib1.tb1.test1", "failed", 3, 10)
        self._add_test_history("lib1.tb1", "lib1.tb1.test2", "failed", 1, 11)
        self._add_test_history("lib1.tb1", "lib1.tb1.test3", "skipped", 1, None)
        self._add_test_history("lib1.tb1", "lib1.tb1.test4", "passed", 1, 13)
        self._add_test_history("lib1.tb1", "lib1.tb1.test5", "passed", 3, 14)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 0:
                self.assertEqual(result[set_idx]["total_exec_time"], 48)
                self.assertEqual(len(result[set_idx]["test_suites"]), 1)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_sets_are_ordered_by_execution_time(self):
        latest_dependency_updates = dict(file1=2, file2=1, file3=2.5)
        test_suites = [
            self._create_test_suite(
                "lib1.tb1",
                ["lib1.tb1.test1", "lib1.tb1.test2", "lib1.tb1.test3", "lib1.tb1.test4", "lib1.tb1.test5"],
                "file1",
            ),
            self._create_test_suite("lib1.tb2", ["lib1.tb2.test1"], "file2"),
            self._create_test_suite("lib1.tb3", ["lib1.tb3.test1"], "file3"),
        ]
        self._add_test_history("lib1.tb1", "lib1.tb1.test1", "failed", 3, 10)
        self._add_test_history("lib1.tb1", "lib1.tb1.test2", "failed", 1, 11)
        self._add_test_history("lib1.tb1", "lib1.tb1.test3", "skipped", 1, None)
        self._add_test_history("lib1.tb1", "lib1.tb1.test4", "passed", 1, 13)
        self._add_test_history("lib1.tb1", "lib1.tb1.test5", "passed", 3, 14)
        self._add_test_history("lib1.tb2", "lib1.tb2.test1", "failed", 3, 9)
        self._add_test_history("lib1.tb3", "lib1.tb3.test1", "failed", 3, 8)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)
        result = test_scheduler._create_test_suite_sets(test_suites)

        for set_idx in range(5):
            if set_idx == 0:
                self.assertEqual(result[set_idx]["total_exec_time"], 65)
                self.assertEqual(len(result[set_idx]["test_suites"]), 3)
                self.assertEqual(result[set_idx]["test_suites"][0]["test_suite"].name, "lib1.tb3")
                self.assertEqual(result[set_idx]["test_suites"][1]["test_suite"].name, "lib1.tb2")
                self.assertEqual(result[set_idx]["test_suites"][2]["test_suite"].name, "lib1.tb1")
            else:
                if set_idx == 2:
                    self.assertIsNone(result[set_idx]["total_exec_time"])
                else:
                    self.assertEqual(result[set_idx]["total_exec_time"], 0)
                self.assertEqual(len(result[set_idx]["test_suites"]), 0)

    def test_that_next_test_suite_is_picked_in_time_order_for_single_thread(self):
        latest_dependency_updates = dict(file1=2, file2=1, file3=2.5, file4=1, file5=1)
        test_suites = [
            self._create_test_suite("lib1.tb1", ["lib1.tb1.test1"], "file1"),
            self._create_test_suite("lib1.tb2", ["lib1.tb2.test1"], "file2"),
            self._create_test_suite("lib1.tb3", ["lib1.tb3.test1"], "file3"),
            self._create_test_suite("lib1.tb4", ["lib1.tb4.test1"], "file4"),
            self._create_test_suite("lib1.tb5", ["lib1.tb5.test1"], "file5"),
        ]

        self._add_test_history("lib1.tb1", "lib1.tb1.test1", "failed", 3, 10)
        self._add_test_history("lib1.tb2", "lib1.tb2.test1", "failed", 3, 9)
        self._add_test_history("lib1.tb4", "lib1.tb4.test1", "passed", 3, 9)

        test_scheduler = TestScheduler(test_suites, 1, latest_dependency_updates, self._test_history)

        with mock.patch("time.time", lambda: 1000):
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb2")
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb1")
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb3")
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb5")
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb4")
            self.assertRaises(StopIteration, test_scheduler.next, thread_id=0)

    def test_that_next_test_suite_is_picked_considering_load_balancing(self):
        latest_dependency_updates = dict(file1=0, file2=0, file3=0, file4=0, file5=0)
        test_suites = [
            self._create_test_suite("lib1.tb1", ["lib1.tb1.test1"], "file1"),
            self._create_test_suite("lib1.tb2", ["lib1.tb2.test1"], "file2"),
            self._create_test_suite("lib1.tb3", ["lib1.tb3.test1"], "file3"),
            self._create_test_suite("lib1.tb4", ["lib1.tb4.test1"], "file4"),
            self._create_test_suite("lib1.tb5", ["lib1.tb5.test1"], "file5"),
        ]

        self._add_test_history("lib1.tb1", "lib1.tb1.test1", "passed", 3, 2)
        self._add_test_history("lib1.tb2", "lib1.tb2.test1", "passed", 3, 3.5)
        self._add_test_history("lib1.tb3", "lib1.tb3.test1", "passed", 3, 3)
        self._add_test_history("lib1.tb4", "lib1.tb4.test1", "passed", 3, 9.5)
        self._add_test_history("lib1.tb5", "lib1.tb5.test1", "passed", 3, 12)

        test_scheduler = TestScheduler(test_suites, 3, latest_dependency_updates, self._test_history)

        with mock.patch("time.time", lambda: 1000):
            self.assertEqual(test_scheduler.next(thread_id=0).name, "lib1.tb5")
            self.assertEqual(test_scheduler.next(thread_id=1).name, "lib1.tb1")
            self.assertEqual(test_scheduler.next(thread_id=2).name, "lib1.tb4")

        with mock.patch("time.time", lambda: 1002):
            test_scheduler.test_done(thread_id=1)
            self.assertEqual(test_scheduler.next(thread_id=1).name, "lib1.tb3")

        with mock.patch("time.time", lambda: 1005):
            test_scheduler.test_done(thread_id=1)
            self.assertEqual(test_scheduler.next(thread_id=1).name, "lib1.tb2")

        with mock.patch("time.time", lambda: 1008.5):
            test_scheduler.test_done(thread_id=1)
            self.assertRaises(StopIteration, test_scheduler.next, thread_id=1)

        with mock.patch("time.time", lambda: 1009.5):
            test_scheduler.test_done(thread_id=2)
            self.assertRaises(StopIteration, test_scheduler.next, thread_id=2)

        self.assertFalse(test_scheduler.is_finished())

        with mock.patch("time.time", lambda: 1012):
            test_scheduler.test_done(thread_id=0)
            self.assertRaises(StopIteration, test_scheduler.next, thread_id=0)

        self.assertTrue(test_scheduler.is_finished())
