.. _run_library:

Run Library User Guide
======================

Introduction
------------

The VHDL run library is a number of VHDL packages providing functionality for running a VUnit testbench. This
functionality, also known as the VHDL test runner (VR), can be used standalone but the highly recommended approach, and
the main focus of this user guide, is to use VR together with the Python-based test runner (PR). More information on the PR can be found in the :doc:`PR user guide <../user_guide>` and the :doc:`PR API documentation <../py/ui>`.

Minimal VUnit Testbench
-----------------------

A (close to) minimal VUnit testbench is outlined below.

.. raw:: html
    :file: img/tb_minimal.html

The code has the following important properties:

* The VUnit functionality is located in the ``vunit_lib`` library and is included with the library and context
  statements in the first two lines.
* The ``runner_cfg`` generic is used to control the testbench from PR. If the VR is used standalone, you will
  need a default value, ``runner_cfg_default``, for the generic. Note that the generic **must** be named
  ``runner_cfg`` for the testbench to be recognized by PR (there is an exception which we'll get to later).
* Every VUnit testbench has a main controlling process. It's labelled ``test_runner`` in this example but the name is
  not important. The process starts by setting up VUnit using the ``test_runner_setup`` procedure with ``runner_cfg`` as
  the second parameter. The first ``runner`` parameter is a globally defined signal used to synchronize activities
  internal to VUnit. The process ends with a call to the ``test_runner_cleanup`` procedure which will perform some
  housekeeping activities and then force the simulation to a stop.
* Since the call to ``test_runner_cleanup`` ends the simulation, you must execute your test code before that.
  You can either place the test code directly between ``test_runner_setup`` and ``test_runner_cleanup`` or you can use that region to trigger and wait for test activities performed externally (for example in a different process). Alternately, you can combine the two strategies. In this case, the test code is within the same process and use the ``check_equal`` procedure from the :doc:`check library <../check/user_guide>`.

Running this testbench using PR will result in the following output (or similar):

.. raw:: html
    :file: img/tb_minimal_stdout.html


Testbench with Test Cases
-------------------------

A VUnit testbench can be structured around a set of test cases called a test suite. Defining test cases is a way of
emphasizing what functionality is being verified by the testbench.

.. raw:: html
    :file: img/test_runner_with_test_cases.html

This testbench has two test cases, named ``Test to_string for integer`` and ``Test to_string for boolean``.
If a test case has been enabled by ``runner_cfg``, the corresponding ``run`` function call will return ``true``
the **first** time it is called, and the test code in that (els)if branch is executed. All test code can be in
that branch, as in the example, or the branch can be used to coordinate activities elsewhere in the testbench.

The ``test_suite`` function returns ``true``, and keeps the loop running, until there are no more enabled test cases
remaining to execute.

Note that registration of test cases is not necessary; PR will scan your testbenches for ``run`` function calls in order
to find all test cases. Also note that the test case name **must** be a string literal or it won't be found by PR.

In case VR is used standalone, the test cases are registered on-the-fly the first time the ``run`` function is called.

A VUnit testbench runs through several distinct *phases* during the course of a simulation. The first is the
``test_runner_setup`` phase implemented by the procedure with the same name, and the last is the ``test_runner_cleanup``
phase. In between, there are a number of setup/cleanup phases for the test suite and the test cases. The code for these
phases, if any, is defined by the user and is placed as indicated by the comments in the example. These phases are
typically used for configuration, resetting the DUT, reading/writing test data from/to file etc. Phases can also be used
to synchronize testbench processes and avoid issues such as premature simulation exits where ``test_runner_cleanup``
ends the simulation before all processes have completed their tasks. For a more comprehensive description of phases,
please refer to the :doc:`VUnit phase blog <../blog/2023_04_01_vunit_phases>` for details.

Running this testbench gives the following output:

.. raw:: html
    :file: img/tb_with_test_cases_stdout.html


Distributed Testbenches
-----------------------

Some testbenches with a more distributed control may have several processes which operations depend on the currently
running test case. However, there can be only one call to the ``run("Name of test case")`` function. Otherwise, VUnit
will think that you've several test cases with the same name, which is not allowed in the same testbench. To avoid this,
you can use the ``running_test_case`` function, which will return the name of the running test case. Below is an example
of how it can be used. The example also contains a few other VUnit features:

* ``info`` is a procedure for logging information. For more details, please refer to the :doc:`logging library user
  guide<../logging/user_guide>`.
* ``start_stimuli`` is a VUnit event used to synchronize the two processes. The ``test_runner`` process activates the
  event using ``notify`` and the ``stimuli_generator`` process waits until the event becomes active using ``is_active``.
  For more details, please refer to the :doc:`event user guide<../data_types/event_user_guide>`.
* ``get_entry_key``, ``lock``, and ``unlock`` are subprograms used to prevent ``test_runner_cleanup`` from ending the
  simulation before the ``stimuli_generator`` process has completed. For more details, please refer to the
  :doc:`VUnit phase blog <../blog/2023_04_01_vunit_phases>`.

.. raw:: html
    :file: img/tb_running_test_case.html

The ``running_test_case`` function returns the name of currently running test case from the call to the ``run``
function of that test case until the next ``run`` function is called. Before the first call to ``run`` or after a call
to ``run`` returning ``false``, this function will return an empty string (``""``).

There's also a similar function, ``active_test_case``, which returns a test case name within all parts of the
``test_suite`` loop. However, this function is not supported when running the testbench standalone without PR.

In the examples described so far the main controlling process has been placed in the top-level entity. It's also
possible to move this to a lower-level entity. To do that the ``runner_cfg`` generic has to be passed down to
that entity. However, the generic in that lower-level entity **must not** be called ``runner_cfg`` since PR
considers every VHDL file with a ``runner_cfg`` generic a top-level testbench to simulate. So the testbench
top-level can look like this

.. raw:: html
    :file: img/tb_with_lower_level_control.html

And the lower-level entity like this

.. raw:: html
    :file: img/test_control.html

The default PR behaviour is to scan all VHDL files with an entity containing a ``runner_cfg`` generic for
test cases to run. Now that that the lower-level entity uses another generic name you have to use the
:doc:`scan_tests_from_file <../py/vunit>` method in your run script.

Controlling What Test Cases to Run
----------------------------------

When working with VUnit you will eventually end up with many testbenches and test cases. For example

.. raw:: html
    :file: img/list.html

You can control what testbenches and test cases to run from the command line by listing their names and/or using
patterns. For example

.. raw:: html
    :file: img/tb_minimal_tb_with_test_cases_stdout.html

PR will simulate matching testbenches and use ``runner_cfg`` to control what test cases to run. Be aware that your
shell may try to match the pattern you specify first. For example, using ``*tb*`` as a pattern will match all previous
test case names, but it will also match all testbench file names - resulting in the file names being passed to VUnit,
and no matching tests being found. However, passing ``.*tb*`` will match all tests but no files.

Running Test Cases Independently
--------------------------------

The test suite while loop presented earlier iterates over all enabled test cases but the default behaviour of
VUnit is to run all test cases in separate simulations, only enabling one test case at a time. There are several
good reasons for this

* The pass/fail status of a test case is based on its own merits and is not a side effect of other test cases.
  This makes it easier to trust the information in the test report.
* A failing test case, causing the simulation to stop, won't prevent the other test cases in the testbench from
  running
* You can save time by just running one of many slow test cases if that's sufficient for a specific test run.
* You can run test cases in parallel threads using the multicore capabilities of your computer. Below all three
  tests are run in parallel using the ``-p`` option. Note the 3x difference between the total simulation time and
  the elapsed time.

.. raw:: html
    :file: img/tb_minimal_tb_running_test_case_tb_with_lower_level_control_stdout.html

Possible drawbacks to this approach are that test cases have to be independent and the overhead
of starting a new simulation for each test case (this is typically less than one second per test case). If that
is the case you can force all test cases of a testbench to be run in the same simulation. This is done by adding
the ``run_all_in_same_sim`` attribute (``-- vunit: run_all_in_same_sim``) before the test suite.

.. raw:: html
    :file: img/tb_run_all_in_same_sim.html


The ``run_all_in_same_sim`` attribute can also be set from the run script, see :class:`vunit.ui.testbench.TestBench`.

.. important::
   When setting ``run_all_in_same_sim`` from the run script, the setting must be identical for all configurations
   of the testbench.

The VUnit Watchdog
------------------

Sometimes your design has a bug causing a test case to stall indefinitely, maybe preventing a nightly test run from
proceeding. To avoid this VUnit provides a watchdog which will timeout and fail a test case after a specified time.

.. raw:: html
    :file: img/tb_with_watchdog.html


Note that the problem with the first test case doesn't prevent the second from running.

.. raw:: html
    :file: img/tb_with_watchdog_stdout.html

What Makes a Test Fail?
-----------------------

Stopping Failures
~~~~~~~~~~~~~~~~~

Anything that stops the simulation before the ``test_runner_cleanup`` procedure is called will cause a failing
test.

.. raw:: html
    :file: img/tb_stopping_failure.html

All but the last of these test cases will fail

.. raw:: html
    :file: img/tb_stopping_failure_stdout.html

By setting the VUnit ``fail_on_warning`` attribute (``-- vunit: fail_on_warning``) before the test suite,
the last test case will also fail.

.. raw:: html
    :file: img/tb_fail_on_warning.html

The ``fail_on_warning`` attribute can also be set from the run script, see :class:`vunit.ui.testbench.TestBench`.

.. important::
   When setting ``fail_on_warning`` from the run script, the setting must be identical for all configurations
   of the testbench.

Counting Errors with VUnit Logging/Check Libraries
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you use the VUnit check/logging library you can set the :doc:`stop_level <../logging/user_guide>` such that the
simulation continues on an error. Such errors will be remembered and the test will fail despite
reaching the ``test_runner_cleanup`` call.

By default ``test_runner_cleanup`` will fail if there were any error
or failure log even if they where disabled. Disabled errors or
failures can be allowed using the ``allow_disabled_errors`` or
``allow_disabled_failures`` flags. Warnings can also optionally cause
failure by setting the ``fail_on_warning`` flag.

.. raw:: html
    :file: img/tb_stop_level.html

.. raw:: html
    :file: img/tb_stop_level_stdout.html

Seeds for Random Number Generation
----------------------------------

The Python test runner automatically generates a 64-bit base seed, which serves as the foundation for deriving new seeds
to initialize one or more random number generators (RNGs) within the simulation. This base seed is calculated using the
system time and a thread identifier, ensuring that it varies between simulations. This variability enhances test
coverage since randomized test will cover different areas in each simulation. By running the same randomized test in
several parallel threads but with different base seeds we can also shorten the execution time while maintaining the same
level of test coverage.

.. note::
    VHDL-2019 introduces an interface for obtaining the system time. However, as of this writing, support for this
    feature is limited, and where available, it only offers second-level resolution. If used for base seed generation,
    simulations in parallel threads would receive the same base seed when started simultaneously.

    To address this, the Python test runner uses system time with microsecond resolution combined with an additional
    thread identifier as the source of entropy. This approach ensures the uniqueness of base seeds across parallel threads.

The base seed is provided via the ``runner_cfg`` generic and new derived seeds can be obtained by calling the
``get_seed`` function with ``runner_cfg`` and a salt string. The salt string is hashed together with the base seed to
ensure the uniqueness of each derived seed (with very high probability). The ``salt`` parameter can be omitted if only a
single seed is needed:

.. raw:: html
    :file: img/get_seed_and_runner_cfg.html

A seed can also be obtained without referencing ``runner_cfg``, which is particularly useful when the seed is created
within a process that is not part of the top-level testbench. However, this is only possible **after**
``test_runner_setup`` has been executed. To prevent race conditions, the ``get_seed`` procedure will block execution
until ``test_runner_setup`` has completed.

.. raw:: html
    :file: img/get_seed_wo_runner_cfg.html

In the previous examples, the ``get_seed`` subprograms returned seeds as strings. However, ``get_seed`` subprograms are
also available for ``integer`` seeds and 64-bit seeds of ``unsigned`` and ``signed`` type. To avoid any ambiguity that
may arise, the following function aliases are defined: ``get_string_seed``, ``get_integer_seed``, ``get_unsigned_seed``,
and ``get_signed_seed``. Additionally, the ``get_uniform_seed`` procedure is provided to support the standard
``uniform`` procedure in ``ieee.math_real``. The ``uniform`` procedure requires two ``positive`` seeds, ``seed1`` and
``seed2``, each with its own specific legal range that is smaller than the full ``positive`` range.

.. raw:: html
    :file: img/get_uniform_seed.html

Reproducibility
~~~~~~~~~~~~~~~

The seed used for a test is logged in the test output file (``<output path>/output.txt``) and, in the event of a test failure, it is also displayed on the console:

.. raw:: html
    :file: img/tb_seed_stdout.html

To reproduce the failing test setup and verify a bug fix, the failing seed can be specified using the ``--seed`` option:

.. raw:: html
    :file: img/seed_option.html

Running A VUnit Testbench Standalone
------------------------------------

A VUnit testbench can be run just like any other VHDL testbench without involving PR. This is not the recommended
way of working but can be useful in an organization which has started to use, but not fully adopted, VUnit. If
you simulate the testbench below without PR the ``runner_cfg`` generic will have the
value ``runner_cfg_default`` which will cause all test cases to be run.

.. raw:: html
    :file: img/tb_standalone.html

However, since PR hasn't scanned the code for test cases VUnit doesn't know how many they are. Instead it will
iterate the while loop as long as there is a call to the ``run`` function with a test case name VUnit hasn't
seen before. The first iteration in the example above will run the *Test that fails on VUnit check procedure* test
case and the second iteration will run *Test to_string for boolean*. Then there is a third iteration where no
new test case is found. This will trigger VUnit to end the while loop.

The default level for a VUnit check like ``check_equal`` is ``error`` and the default behaviour is to stop the
simulation on ``error`` when running with PR. When running standalone the default behaviour is to stop the
simulation on the ``failure`` level such that the simulation has the ability to run through all test cases
despite a failing check like in the example above.

Without PR there is a need to print the test result. VUnit provides the ``get_checker_stat`` function to get the
internal error counters and a ``to_string`` function to convert the returned record to a string. The example
uses that and VUnit logging capabilities to create a simple summary in the test suite cleanup phase.

It's also useful to print the currently running test case. VR has an internal logger, ``runner``, providing
such information. This information is suppressed when running with PR but is enabled in the standalone mode

.. code-block:: text

    #             0 ps - runner  -    INFO  - Test case: Test that fails on VUnit check procedure
    #             0 ps - check   -    ERROR - Equality check failed - Got 17. Expected 18.
    #             0 ps - runner  -    INFO  - Test case: Test to_string for boolean
    #             0 ps - default -    INFO  - ===Summary===
    #                                         checker_stat'(n_checks => 2, n_failed => 1, n_passed => 1)

Note that VUnit cannot handle VHDL asserts in this mode of operation. If the simulator has full support for VHDL-2019,
it is possible to read out assert error counters and use ``check_equal`` to verify that these are zero before calling
``test_runner_cleanup``. Failures like division by zero or out of range operations are other examples that won't be
handle gracefully in this mode, and not something that VHDL provides any solutions for.

Special Paths
-------------

When running with PR you can get the path to the directory containing the testbench and the path to the output
directory of the current test by using the ``tb_path`` and ``output_path`` generics. This is described in more
detail :doc:`here <../user_guide>`. It's also possible to access these path strings from the ``runner_cfg``
generic by using the ``tb_path`` and ``output_path`` functions.

Running the following testbench

.. raw:: html
    :file: img/tb_magic_paths.html

will reveal that

.. raw:: html
    :file: img/tb_magic_paths_stdout.html

Note On Undocumented Features
-----------------------------

VR contains a number of features not documented in this guide. These features are under evaluation and will be
documented or removed when that evaluation has completed.
