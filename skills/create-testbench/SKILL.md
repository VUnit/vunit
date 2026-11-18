---
name: create-testbench
description: Create and implement VUnit VHDL testbenches for HDL designs, including incomplete designs or entity definitions for test-driven development (TDD). Use when generating a testbench, adding verification tests, or developing tests before implementing the DUT.
license: MPL-2.0
---

# Create a VUnit Testbench

1. **Inspect the DUT interface and requirements.** Read the available HDL declarations, specifications, and existing project conventions. The DUT implementation need not exist yet; support test-driven development from an entity definition alone. Identify meaningful tests based on the intended behavior, and clarify essential ambiguities rather than assuming undocumented behavior.

2. **Generate the testbench.** Use the VUnit command-line tool (vunit create-testbench) to generate testbench scaffolding rather than writing it manually. Run `vunit create-testbench --help` to discover its current interface. Use noninteractive options and `--preview` where available. Do not overwrite existing files without authorization.

3. **Create test scaffolding.** Where supported, pass the proposed test names to the VUnit generator so it creates their `run(...)` branches. If no tests are specified, the generator creates a placeholder test named `first_test`.

4. **Handle unfinished tests.** Generated tests are marked with the VUnit `.todo` attribute and contain an `error()` call so they cannot pass silently:

   When no tests were specified:

   ```vhdl
   if run("first_test") then
     -- vunit: .todo
     error("Tests have yet to be added");
   ```

   When named tests were specified:

   ```vhdl
   if run("fifo_overflow") then
     -- vunit: .todo
     error("This test has yet to be implemented");
   ```

   Implement the requested tests, removing their `.todo` attributes and placeholder errors only when meaningful verification logic is in place. Report any unfinished tests to the user.

5. **Use VUnit's checking facilities.** Prefer VUnit check procedures and functions over plain VHDL assertions for functional verification. Consult the [Check Library User Guide](https://vunit.github.io/check/user_guide.html) and its linked API documentation.

6. **Configure a watchdog.** Use `test_runner_watchdog` with a timeout appropriate for the expected simulation duration. Refer to the [Run Library User Guide](https://vunit.github.io/run/user_guide.html). This watchdog measures simulation time, not wall-clock time.

7. **Implement the tests.** Choose appropriate stimulus, reference models, and checking strategies. Reuse relevant VUnit facilities and existing project conventions. Consult the [VUnit HDL Libraries documentation](https://vunit.github.io/hdl_libraries.html) as needed.

8. **Validate.** Compile and run the relevant tests where a simulator is available. Investigate failures and report any remaining problems. For TDD, a test failing because the DUT implementation is incomplete can be an expected development outcome; distinguish this from a broken testbench or configuration. Do not describe unfinished test scaffolding as completed verification.

Keep changes focused on the requested testbench and avoid modifying unrelated RTL or project files.