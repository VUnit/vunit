.. _run_library:

Run Library
===========

Introduction
------------

The VHDL run library is a number of VHDL packages providing functionality for running a VUnit testbench.
This functionality is also known as the VHDL test runner (VR). It's possible to run a VUnit testbench standalone,
just using VR, but the highly recommended approach and the main focus of this user guide is to use VR together
with the Python-based test runner (PR) documented in this :doc:`user guide <../user_guide>` and
:doc:`API documentation <../py/ui>`.

Minimal VUnit Testbench
-----------------------

A (close to) minimal VUnit testbench looks like this

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_minimal is
      generic (runner_cfg : string := runner_cfg_default);
    end entity;

    architecture tb of tb_minimal is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);
        check_equal(to_string(17), "17");
        test_runner_cleanup(runner);
      end process;
    end architecture;

It has the following important properties

- The VUnit functionality is located in the ``vunit_lib`` library and is included with the library and context
  statements in the first two lines.
- The ``runner_cfg`` generic is used to control the testbench from PR. If the testbench is used standalone you will
  need a default value, ``runner_cfg_default``, for the generic. Note that the generic **must** be named
  ``runner_cfg`` for the testbench to be recognized by PR (there is an exception which we'll get to later).
- Every VUnit testbench has a main controlling process. It's labelled ``test_runner`` in this example but the name
  is not important. The process starts by setting up VUnit using the ``test_runner_setup`` procedure with
  ``runner_cfg`` as the second parameter. ``runner`` is a globally defined signal used to synchronize activities
  internal to VUnit. The process ends with a call to the ``test_runner_cleanup`` procedure which will force the
  simulation to a stop.
- Since the call to ``test_runner_cleanup`` ends the simulation you'll need to execute your test code before that.
  You can put the test code directly between ``test_runner_setup`` and ``test_runner_cleanup`` or you can simply
  use that region to trigger and wait for test activities performed elsewhere (for example in other processes) or
  you can mix those strategies. In this case the test code is in the same process and it uses the ``check_equal``
  procedure from the :doc:`check library <../check/user_guide>`

Running this testbench using PR will result in something like this

.. code-block:: console

    > python run.py
    Starting lib.tb_minimal.all
    pass (P=1 S=0 F=0 T=1) lib.tb_minimal.all (1.1 seconds)

    ==== Summary ==============================
    pass lib.tb_minimal.all (1.1 seconds)
    ===========================================
    pass 1 of 1
    ===========================================
    Total time was 1.1 seconds
    Elapsed time was 1.1 seconds
    ===========================================
    All passed!

Testbench with Test Cases
-------------------------

A VUnit testbench can be structured around a set of test cases called a test suite. This will emphasize the
functionality being verified by the testbench.

.. code-block:: vhdl

    test_runner : process
    begin
      test_runner_setup(runner, runner_cfg);

      -- Put test suite setup code here

      while test_suite loop

        -- Put common test case setup code here

        if run("Test to_string for integer") then
          check_equal(to_string(17), "17");
        elsif run("Test to_string for boolean") then
          check_equal(to_string(true), "true");
        end if;

        -- Put common test case cleanup code here

      end loop;

      -- Put test suite cleanup code here

      test_runner_cleanup(runner);
    end process;

This testbench has two test cases named *Test to_string for integer* and *Test to_string for boolean*.
If a test case has been enabled by the ``runner_cfg`` the corresponding ``run`` function call will return ``true``
the **first** time it is called and the test code in that (els)if branch is executed. All test code can be in
the branch as in the example or the branch can be used to coordinate activities elsewhere in the testbench.

``test_suite`` is a function that will return ``true`` and keep the while loop running as long as there are
enabled test cases left to run.

Note that there is no need to register the test cases anywhere. PR will scan your testbenches for ``run`` function
calls to find all test cases. These ``run``  functions must have a string literal as the name parameter to be
found by PR.

A VUnit testbench naturally runs through a number of *phases*. The first is the test runner setup phase implemented
by the procedure with the same name and the last is the test runner cleanup phase. In between there are a number
of setup/cleanup phases for the test suite and the test cases. The code for these phases, if any, is defined by the
user and it's placed as indicated by the comments in the example. These phases are typically used for things like
setting up support packages, resetting the DUT, reading/writing test data from/to file, and synchronizing
testbench activities.

Running this testbench gives the following output

.. code-block:: console

    > python run.py
    Starting lib.tb_with_test_cases.Test to_string for integer
    pass (P=1 S=0 F=0 T=2) lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)

    Starting lib.tb_with_test_cases.Test to_string for boolean
    pass (P=2 S=0 F=0 T=2) lib.tb_with_test_cases.Test to_string for boolean (1.1 seconds)

    ==== Summary =============================================================
    pass lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)
    pass lib.tb_with_test_cases.Test to_string for boolean (1.1 seconds)
    ==========================================================================
    pass 2 of 2
    ==========================================================================
    Total time was 2.1 seconds
    Elapsed time was 2.1 seconds
    ==========================================================================
    All passed!

Distributed Testbenches
-----------------------

Some testbenches with a more distributed control may have several processes which operations depend on the
currently running test case. However, there can be only one call to the ``run("Name of test case")`` function
or VUnit will think that you've several test cases with the same name and that is not allowed (in the same
testbench). The way to solve this is to use the ``running_test_case`` function which will return the name of the
running test case. Here is an example of how it can be used (``info`` is a procedure from the
:doc:`logging library <../logging/user_guide>`).

.. code-block:: vhdl

    architecture tb of tb_running_test_case is
      signal start_stimuli, stimuli_done : boolean := false;
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
          if run("Test scenario A") or run("Test scenario B") then
            start_stimuli <= true;
            wait until stimuli_done;
          elsif run("Test something else") then
            info("Testing something else");
          end if;
        end loop;

        test_runner_cleanup(runner);
      end process;

      stimuli_generator: process is
      begin
        wait until start_stimuli;

        if running_test_case = "Test scenario A" then
          info("Applying stimuli for scenario A");
        elsif running_test_case = "Test scenario B" then
          info("Applying stimuli for scenario B");
        end if;

        stimuli_done <= true;
      end process stimuli_generator;

    end architecture;

``running_test_case`` will return the test case name when the ``run`` function for the currently running test case
has been called and continue to return that name until a ``run`` function has been called again. Before the first
call to ``run`` or after a call to ``run`` returning ``false`` ``running_test_case`` will return the empty string
(``""``).

There's also a similar function ``active_test_case`` which returns a test case name within all parts of the
``test_suite`` loop. However, this function is not supported when running the testbench standalone without PR.
This mode of operation is described later in this guide.

In the examples described so far the main controlling process has been placed in the top-level entity. It's also
possible to move this to a lower-level entity. To do that the ``runner_cfg`` generic has to be passed down to
that entity. However, the generic in that lower-level entity **must not** be called ``runner_cfg`` since PR
considers every VHDL file with a ``runner_cfg`` generic a top-level testbench to simulate. So the testbench
top-level can look like this

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_with_lower_level_control is
      generic (runner_cfg : string := runner_cfg_default);
    end entity;

    architecture tb of tb_with_lower_level_control is
    begin

      test_control: entity work.test_control
        generic map (
          nested_runner_cfg => runner_cfg);

    end architecture;

And the lower-level entity like this

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity test_control is
      generic (
        nested_runner_cfg : string);
    end entity test_control;

    architecture tb of test_control is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, nested_runner_cfg);

        while test_suite loop
          if run("Test something") then
            info("Testing something");
          elsif run("Test something else") then
            info("Testing something else");
          end if;
        end loop;

        test_runner_cleanup(runner);
      end process;
    end architecture tb;


The default PR behaviour is to scan all VHDL files with an entity containing a ``runner_cfg`` generic for
test cases to run. Now that that the lower-level entity uses another generic name you have to use the
:doc:`scan_tests_from_file <../py/vunit>` method in your run script.

Controlling What Test Cases to Run
----------------------------------

When working with VUnit you will eventually end up with many testbenches and test cases. So far we have

.. code-block:: console

    > python run.py --list
    lib.tb_minimal.all
    lib.tb_running_test_case.Test scenario A
    lib.tb_running_test_case.Test scenario B
    lib.tb_running_test_case.Test something else
    lib.tb_with_lower_level_control.all
    lib.tb_with_test_cases.Test to_string for integer
    lib.tb_with_test_cases.Test to_string for boolean
    Listed 7 tests

You can control what testbenches and test cases to run from the command line by listing their names and/or using
patterns. For example

.. code-block:: console

    > python run.py *min* *integer
    Starting lib.tb_minimal.all
    pass (P=1 S=0 F=0 T=2) lib.tb_minimal.all (1.0 seconds)

    Starting lib.tb_with_test_cases.Test to_string for integer
    pass (P=2 S=0 F=0 T=2) lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)

    ==== Summary =============================================================
    pass lib.tb_minimal.all                                (1.0 seconds)
    pass lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)
    ==========================================================================
    pass 2 of 2
    ==========================================================================
    Total time was 2.1 seconds
    Elapsed time was 2.1 seconds
    ==========================================================================
    All passed!

PR will simulate matching testbenches and use ``runner_cfg`` to control what test cases to run.

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

.. code-block:: console

    > python run.py -p3 *min* *test_cases*
    Starting lib.tb_minimal.all
    Starting lib.tb_with_test_cases.Test to_string for integer
    Starting lib.tb_with_test_cases.Test to_string for boolean
    pass (P=1 S=0 F=0 T=3) lib.tb_minimal.all (1.0 seconds)

    pass (P=2 S=0 F=0 T=3) lib.tb_with_test_cases.Test to_string for boolean (1.1 seconds)

    pass (P=3 S=0 F=0 T=3) lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)

    ==== Summary =============================================================
    pass lib.tb_minimal.all                                (1.0 seconds)
    pass lib.tb_with_test_cases.Test to_string for boolean (1.1 seconds)
    pass lib.tb_with_test_cases.Test to_string for integer (1.1 seconds)
    ==========================================================================
    pass 3 of 3
    ==========================================================================
    Total time was 3.2 seconds
    Elapsed time was 1.1 seconds
    ==========================================================================
    All passed!

Possible drawbacks to this approach are that test cases have to be independent and the overhead
of starting a new simulation for each test case (this is typically less than one second per test case). If that
is the case you can force all test cases of a testbench to be run in the same simulation. This is done by adding
the ``run_all_in_same_sim`` attribute.

.. code-block:: vhdl

    -- vunit: run_all_in_same_sim

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_with_test_cases is
      generic (runner_cfg : string := runner_cfg_default);
    end entity;

    architecture tb of tb_with_test_cases is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
          if run("Test to_string for integer") then
            check_equal(to_string(17), "17");
          elsif run("Test to_string for boolean") then
            check_equal(to_string(true), "true");
          end if;
        end loop;

        test_runner_cleanup(runner);
      end process;
    end architecture;

The VUnit Watchdog
------------------

Sometimes your design has a bug causing a test case to stall indefinitely, maybe preventing a nightly test run from
proceeding. To avoid this VUnit provides a watchdog which will timeout and fail a test case after a specified time.

.. code-block:: vhdl

    architecture tb of tb_with_watchdog is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
          if run("Test that stalls") then
            wait;
          elsif run("Test to_string for boolean") then
            check_equal(to_string(true), "true");
          elsif run("Test that needs longer timeout") then
            -- It is also possible to set/re-set the timeout
            -- When test cases need separate timeout settings
            set_timeout(runner, 2 ms);
            wait for 1 ms;
          end if;
        end loop;

        test_runner_cleanup(runner);
      end process;

      test_runner_watchdog(runner, 10 ms);
    end architecture;

Note that the problem with the first test case doesn't prevent the second from running.

.. code-block:: console

    > python run.py *watchdog*
    Starting lib.tb_with_watchdog.Test that stalls
      10000000000000 fs - runner -   ERROR - Test runner timeout after 10000000000000 fs.
    D:\Programming\github\vunit\vunit\vhdl\core\src\core_pkg.vhd:84:7:@10ms:(report failure): Stop simulation on log level error
    C:\ghdl\dev\bin\ghdl.exe:error: report failed
      from: vunit_lib.core_pkg.core_failure at core_pkg.vhd:84
      from: vunit_lib.logger_pkg.count_log at logger_pkg-body.vhd:563
      from: vunit_lib.logger_pkg.log at logger_pkg-body.vhd:711
      from: vunit_lib.logger_pkg.error at logger_pkg-body.vhd:752
      from: vunit_lib.run_pkg.test_runner_watchdog at run.vhd:368
      from: process lib.tb_with_watchdog(tb).P0 at tb_with_watchdog.vhd:25
    C:\ghdl\dev\bin\ghdl.exe:error: simulation failed
    fail (P=0 S=0 F=1 T=2) lib.tb_with_watchdog.Test that stalls (0.3 seconds)

    Starting lib.tb_with_watchdog.Test to_string for boolean
    pass (P=1 S=0 F=1 T=2) lib.tb_with_watchdog.Test to_string for boolean (0.3 seconds)

    ==== Summary ===========================================================
    pass lib.tb_with_watchdog.Test to_string for boolean     (0.3 seconds)
    pass lib.tb_with_watchdog.Test that needs longer timeout (0.3 seconds)
    fail lib.tb_with_watchdog.Test that stalls               (0.3 seconds)
    ========================================================================
    pass 1 of 2
    fail 1 of 2
    ========================================================================
    Total time was 0.5 seconds
    Elapsed time was 0.5 seconds
    ========================================================================


What Makes a Test Fail?
-----------------------

Stopping Failures
~~~~~~~~~~~~~~~~~

Anything that stops the simulation before the ``test_runner_cleanup`` procedure is called will cause a failing
test.


.. code-block:: vhdl

    test_runner : process
      variable my_vector : integer_vector(1 to 17);
    begin
      test_runner_setup(runner, runner_cfg);

      while test_suite loop
        if run("Test that fails on an assert") then
          assert false;
        elsif run("Test that crashes on boundary problems") then
          report to_string(my_vector(runner_cfg'length));
        elsif run("Test that fails on VUnit check procedure") then
          check_equal(17, 18);
        end if;
      end loop;

      test_runner_cleanup(runner);
    end process;

All these test cases will fail

.. code-block:: console

    > python run.py *ways*
    Starting lib.tb_many_ways_to_fail.Test that fails on an assert
    d:\Programming\github\vunit\examples\vhdl\run\tb_many_ways_to_fail.vhd:17:9:@0ms:(assertion error): Assertion violation
    C:\ghdl\dev\bin\ghdl.exe:error: assertion failed
      from: process lib.tb_many_ways_to_fail(tb).test_runner at tb_many_ways_to_fail.vhd:17
    C:\ghdl\dev\bin\ghdl.exe:error: simulation failed
    fail (P=0 S=0 F=1 T=3) lib.tb_many_ways_to_fail.Test that fails on an assert (0.3 seconds)

    Starting lib.tb_many_ways_to_fail.Test that crashes on boundary problems
    C:\ghdl\dev\bin\ghdl.exe:error: bound check failure at d:\Programming\github\vunit\examples\vhdl\run\tb_many_ways_to_fail.vhd:19
      from: process lib.tb_many_ways_to_fail(tb).test_runner at tb_many_ways_to_fail.vhd:19
    C:\ghdl\dev\bin\ghdl.exe:error: simulation failed
    fail (P=0 S=0 F=2 T=3) lib.tb_many_ways_to_fail.Test that crashes on boundary problems (0.3 seconds)

    Starting lib.tb_many_ways_to_fail.Test that fails on VUnit check procedure
                   0 fs - check                -   ERROR - Equality check failed - Got 17. Expected 18.
    D:\Programming\github\vunit\vunit\vhdl\core\src\core_pkg.vhd:84:7:@0ms:(report failure): Stop simulation on log level error
    C:\ghdl\dev\bin\ghdl.exe:error: report failed
      from: vunit_lib.core_pkg.core_failure at core_pkg.vhd:84
      from: vunit_lib.logger_pkg.count_log at logger_pkg-body.vhd:563
      from: vunit_lib.logger_pkg.log at logger_pkg-body.vhd:711
      from: vunit_lib.checker_pkg.failing_check at checker_pkg.vhd:238
      from: vunit_lib.check_pkg.check_equal at check.vhd:3544
      from: vunit_lib.check_pkg.check_equal at check.vhd:3501
      from: process lib.tb_many_ways_to_fail(tb).test_runner at tb_many_ways_to_fail.vhd:21
    C:\ghdl\dev\bin\ghdl.exe:error: simulation failed
    fail (P=0 S=0 F=3 T=3) lib.tb_many_ways_to_fail.Test that fails on VUnit check procedure (0.3 seconds)

    ==== Summary =============================================================================
    fail lib.tb_many_ways_to_fail.Test that fails on an assert             (0.3 seconds)
    fail lib.tb_many_ways_to_fail.Test that crashes on boundary problems   (0.3 seconds)
    fail lib.tb_many_ways_to_fail.Test that fails on VUnit check procedure (0.3 seconds)
    ==========================================================================================
    pass 0 of 3
    fail 3 of 3
    ==========================================================================================
    Total time was 0.8 seconds
    Elapsed time was 0.8 seconds
    ==========================================================================================
    Some failed!

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

.. code-block:: vhdl

    test_runner : process
    begin
      test_runner_setup(runner, runner_cfg);
      set_stop_level(failure);

      while test_suite loop
        if run("Test that fails multiple times but doesn't stop") then
          check_equal(17, 18);
          check_equal(17, 19);
        end if;
      end loop;

      test_runner_cleanup(runner);
    end process;

.. code-block:: console

    > python run.py *count*
    Starting lib.tb_counting_errors.Test that fails multiple times but doesn't stop
                   0 fs - check                -   ERROR - Equality check failed - Got 17. Expected 18.
                   0 fs - check                -   ERROR - Equality check failed - Got 17. Expected 19.
    FAILURE - Logger check has 2 errors
    fail (P=0 S=0 F=1 T=1) lib.tb_counting_errors.Test that fails multiple times but doesn't stop (0.3 seconds)

    ==== Summary ==================================================================================
    fail lib.tb_counting_errors.Test that fails multiple times but doesn't stop (0.3 seconds)
    ===============================================================================================
    pass 0 of 1
    fail 1 of 1
    ===============================================================================================
    Total time was 0.3 seconds
    Elapsed time was 0.3 seconds
    ===============================================================================================
    Some failed!


Running A VUnit Testbench Standalone
------------------------------------

A VUnit testbench can be run just like any other VHDL testbench without involving PR. This is not the recommended
way of working but can be useful in an organization which has started to use, but not fully adopted, VUnit. If
you simulate the testbench below without PR the ``runner_cfg`` generic will have the
value ``runner_cfg_default`` which will cause all test cases to be run.

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_standalone is
      generic (runner_cfg : string := runner_cfg_default);
    end entity;

    architecture tb of tb_standalone is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
          if run("Test that fails on VUnit check procedure") then
            check_equal(17, 18);
          elsif run("Test to_string for boolean") then
            check_equal(to_string(true), "true");
          end if;
        end loop;

        info("===Summary===" & LF & to_string(get_checker_stat));

        test_runner_cleanup(runner);
      end process;
    end architecture;

However, since PR hasn't scanned the code for test cases VUnit doesn't know how many they are. Instead it will
iterate the while loop as long as there is a call to the ``run`` function with a test case name VUnit hasn't
seen before. The first iteration in the example above will run the *Test that fails on VUnit check procedure* test
case and the second iteration will run *Test to_string for boolean*. Then there is a third iteration where no
new test case is found. This will trigger VUnit to end the while loop.

The default level for a VUnit check like ``check_equal`` is ``error`` and the default behaviour is to stop the
simulation on ``error`` when running with PR. When running standalone the default behaviour is to stop the
simulation on the ``failure`` level such that the simulation has the ability to run through all test cases
despite a failing check like in the example above.

Without PR there is a need print the test result. VUnit provides the ``get_checker_stat`` function to get the
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

Note that VUnit cannot handle VHDL asserts in this mode of operation. We will have to wait for VHDL-2017 to get
the ability to read error counters based on assert statements. Failures like division by zero or out of range
operations are other examples that won't be handle gracefully in this mode and not something that VHDL-2017 will
solve.

Special Paths
-------------

When running with PR you can get the path to the directory containing the testbench and the path to the output
directory of the current test by using the ``tb_path`` and ``output_path`` generics. This is described in more
detail :doc:`here <../user_guide>`. It's also possible to access these path strings from the ``runner_cfg``
generic by using the ``tb_path`` and ``output_path`` functions.

Running the following testbench

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_magic_paths is
      generic (runner_cfg : string);
    end entity;

    architecture tb of tb_magic_paths is
    begin
      test_runner : process
      begin
        test_runner_setup(runner, runner_cfg);
        info("Directory containing testbench: " & tb_path(runner_cfg));
        info("Test output directory: " & output_path(runner_cfg));
        test_runner_cleanup(runner);
      end process;
    end architecture;

will reveal that

.. code-block:: console

    > python run.py -v *tb_magic*
    Running test: lib.tb_magic_paths.all
    Running 1 tests

    Starting lib.tb_magic_paths.all
                   0 fs - default              -    INFO - Directory containing testbench: d:/Programming/github/vunit/examples/vhdl/run/
                   0 fs - default              -    INFO - Test output directory: d:/Programming/github/vunit/examples/vhdl/run/vunit_out/test_output/lib.tb_magic_paths.all_243b3c717ce1d4e82490245d1b7e8fe8797f5e94/


Note On Undocumented Features
-----------------------------

VR contains a number of features not documented in this guide. These features are under evaluation and will be
documented or removed when that evaluation has completed.
