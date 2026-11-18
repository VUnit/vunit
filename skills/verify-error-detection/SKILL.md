---
name: verify-error-detection
description: Implement and verify expected error detection in VUnit VHDL testbenches and simulation-only RTL checkers. Use when testing protocol violations, invalid operations, assertion mechanisms, or other conditions that should produce diagnostic errors.
license: MPL-2.0
---

# Verify Error Detection with VUnit

1. **Identify expected errors.** Determine which conditions violate the specified protocol and what diagnostic messages should be produced. Do not assume an operation is illegal without an explicit requirement. For example, withdrawing an arbiter request before receiving a grant is a violation only when the protocol requires requests to remain asserted.

   Tests that intentionally trigger errors are normal regression tests: they must pass when the expected errors are correctly detected. Do not mark them `.xfail`.

2. **Keep RTL checkers simulation-only.** When error-detection logic is embedded in RTL but is not intended for synthesis, enclose it and any verification-only state in synthesis translate pragmas:

   ```vhdl
   -- pragma translate_off
   -- Simulation-only error detection
   -- pragma translate_on
   ```

   Keep functional RTL outside these regions. Use VUnit's mockable logging facilities for errors that the testbench needs to verify. Ordinary VHDL `assert` statements cannot be intercepted by VUnit logging mocks.

3. **Mock expected errors.** Use VUnit's logging library to intercept expected errors rather than allowing them to fail the test. Check the expected logger, message, and severity.

   For example, consider an arbiter whose protocol requires a requester to keep `req(i)` asserted until it has observed `grant(i)` at a rising clock edge. A test can deliberately withdraw an ungranted request and verify that the protocol checker detects it:

   ```vhdl
   mock(arbiter_logger, error);

   -- Assert requests from two clients.
   -- Withdraw one request before it receives a grant.
   -- Allow the arbiter's protocol checker to run.

   check_only_log(
     arbiter_logger,
     "Request withdrawn before grant",
     error
   );

   unmock(arbiter_logger);
   ```

   Use `check_only_log` when exactly one error is expected. Use `check_log` for sequences of expected messages, followed by `unmock` to verify that no unchecked messages remain. Ensure the RTL checker and testbench use the same logger.

4. **Do not inspect simulation logs to verify expected errors.** Searching log output for an expected string is not a reliable substitute for VUnit's logging mocks.

   **Discouraged approach:**

   ```python
   # Finding a string does not prove that the intended
   # protocol checker detected the violation.
   assert "Request withdrawn before grant" in simulation_log
   ```

   Log inspection can be misleading because messages may come from unrelated sources, stale output, or incorrectly handled failures. It does not establish that the intended logger produced the message at the expected severity, or that no additional unexpected errors occurred.

   Use logging mocks for verification. Use simulation logs for diagnosing unexpected failures.

5. **Verify both outcomes.** Check that the correct error is produced when an invalid condition occurs and that valid operation produces no unexpected errors. Missing expected errors, incorrect diagnostics, or additional unexpected errors must fail the test. Restore normal logging after each mocked scenario.

6. **Run the tests.** Execute the relevant tests using the project's VUnit `run.py` script. Keep tests of error-detection mechanisms in the normal passing regression. Investigate failures rather than suppressing them or marking them `.xfail`.

Consult the [VUnit Logging Library User Guide](https://vunit.github.io/logging/user_guide.html#mocking) for the mocking API and examples.

Keep error-detection tests focused, deterministic, and independent of log-file formatting.