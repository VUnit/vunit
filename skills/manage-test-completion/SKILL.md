---
name: manage-test-completion
description: Prevent premature completion of VUnit VHDL tests with concurrent processes using test runner phase locks. Use when background drivers, monitors, checkers, or queued transactions must finish before simulation ends, especially when verification processes operate independently.
license: MPL-2.0
---

# Manage Test Completion with VUnit

1. **Identify outstanding work.** In a concurrent testbench, the main test runner may finish before other processes have completed their tasks. Determine which processes have work that must finish before the test ends, such as checking outstanding transactions or completing stimulus generation.

2. **Use VUnit phase locks.** Prevent premature simulation termination by locking the entry gate of `test_runner_cleanup`. Each independently responsible process can acquire its own key and manage its lock without requiring the test runner to wait for a dedicated completion signal.

   ```vhdl
   checker : process
     constant cleanup_key : key_t := get_entry_key(test_runner_cleanup);
   begin
     -- When verification work becomes outstanding:
     lock(runner, cleanup_key);

     -- Perform the required verification work.

     -- When all outstanding work has been completed:
     unlock(runner, cleanup_key);
   end process;
   ```

   This illustrates the mechanism, not a complete checker. Acquire the lock before cleanup can proceed, and release it only when the process has completed its responsibilities.

3. **Track completion, not elapsed time.** A process should release its lock based on actual completion of its work, not after an arbitrary simulation delay. When using queues, account for both queued and in-progress transactions. An empty queue alone does not prove completion if a transaction has already been removed but has not yet been verified.

4. **Avoid synchronization races.** When combining queues, events, and phase locks, use this pattern:

   ```vhdl
   checker : process
     constant cleanup_key : key_t := get_entry_key(test_runner_cleanup);
   begin
     loop
       if is_empty(work_queue) then
         wait until is_active(work_available);
       end if;

       lock(runner, cleanup_key);

       -- Process and verify queued work, including
       -- waiting for any required DUT responses.

       if is_empty(work_queue) then
         unlock(runner, cleanup_key);
       end if;
     end loop;
   end process;
   ```

   Keep the unlock operation at the end, after completing the current work. Do not combine `unlock` and an event wait under a single queue-empty check. `unlock` can consume delta cycles, during which new work may arrive and its notification may be missed. Checking the queue again at the beginning of the next iteration avoids this race.

5. **Keep completion responsibility local.** Let each process responsible for outstanding work manage its own lock. Multiple processes can independently prevent cleanup until they have finished. Do not introduce a central completion coordinator when phase locks already solve the problem.

6. **Diagnose stalled work.** A phase lock can leave the simulation waiting indefinitely if the responsible process gets stuck. Use suitable timeout mechanisms to identify stalled operations rather than releasing locks merely to let the test pass.

   **Local wait timeouts** are useful when a specific operation has a known maximum duration. Follow a timed wait with a check that fails if the expected condition was not met:

   ```vhdl
   -- Wait for a DUT response, assuming response_valid is low.
   wait until response_valid = '1' for 1 us;
   check(response_valid = '1', "Timed out waiting for DUT response");
   ```

   **Watchdog diagnostics** are useful as a broader safety net. Instrument potentially blocking waits using VUnit's `vunit_error` event and `log_active` to identify where processes are waiting when an error occurs:

   ```vhdl
   checker : process
     constant checker_logger : logger_t := get_logger("checker");
   begin
     wait until (rising_edge(clk) and response_valid = '1')
       or log_active(
         vunit_error,
         decorate("while waiting for a DUT response"),
         logger => checker_logger
       );

     -- Verify the response.
   end process;
   ```

   When the watchdog activates `vunit_error`, `log_active` reports the event along with the supplied context. It always returns `false`, so it does not release the wait or change normal testbench behavior.

   Choose the approach appropriate for the situation. Local timeouts and watchdog diagnostics can also be combined.

7. **Validate completion behavior.** Verify that the test does not finish while required work remains and that cleanup proceeds once all work is complete. Check that missing DUT responses cannot produce a falsely passing test.

Consult the [VUnit Phases article](https://vunit.github.io/blog/2023_04_01_vunit_phases.html), [VUnit Events article](https://vunit.github.io/blog/2023_03_31_vunit_events.html), and [Run Library User Guide](https://vunit.github.io/run/user_guide.html) for phase locks, error events, and watchdog diagnostics.