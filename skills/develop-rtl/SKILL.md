---
name: develop-rtl
description: Develop and verify VHDL RTL from behavioral specifications using VUnit, including optional test-driven development. Use when implementing hardware modules, developing RTL alongside verification tests, or iteratively debugging RTL against requirements.
license: MPL-2.0
---

# Develop RTL with VUnit

1. **Understand the specification.** Inspect the available HDL interfaces, requirements, and project conventions. Clarify ambiguities that affect observable behavior, especially clock-cycle timing, reset behavior, and protocol rules. Do not invent undocumented requirements.

2. **Set up VUnit.** Reuse an existing VUnit project when available. Otherwise, follow the `create-project` skill and use `vunit create-project`. Follow the `create-testbench` skill and use `vunit create-testbench` for new testbenches. Use `--help` to discover the tools' interfaces and `--preview` before generating files.

3. **Develop RTL and tests.** Choose an appropriate development order. Test-driven development is an option, not a requirement. Derive meaningful tests from the specification and implement synthesizable RTL that satisfies it. Follow relevant VUnit skills for verification-specific guidance.

4. **Track incomplete work and expected errors.**

Unfinished tests: Mark tests with incomplete verification logic using .todo, following the create-testbench skill.

Unimplemented RTL functionality: Mark fully implemented tests expected to fail because the RTL does not yet satisfy the specification using .xfail. Remove .xfail when the RTL is completed and the test passes. The final implementation should have no remaining .todo or .xfail tests.

Expected error detection: Tests that deliberately trigger protocol violations or other diagnostic errors are permanent regression tests. Follow the verify-error-detection skill to verify expected errors using VUnit logging mocks. Such tests must pass when error detection works correctly and must not be marked .xfail.

.todo and .xfail are ordinary VUnit attributes; they do not change VUnit's pass/fail reporting.

5. **Run the tests.** Use the project's `run.py` script to compile and execute tests. Generate an xUnit XML report using `-x`, for example:

   ```bash
   python run.py -x vunit_out/agent-results.xml
   ```

   Use a report path appropriate for the project and ensure the results belong to the current execution. Read the XML to identify test outcomes and inspect captured output for failures. Consult terminal output and original simulation logs when additional diagnostics are needed or when no report was generated.

6. **Diagnose and iterate.** Determine whether failures originate in the RTL, testbench, specification interpretation, or project configuration. Make targeted corrections and rerun the relevant tests, then the full suite. Do not weaken valid tests merely to obtain passing results.

7. **Report the result.** Summarize the implementation, verification coverage, tests executed, passing tests, expected failures, unexpected failures, and unresolved issues. Never claim success for tests that have not passed or verification that remains incomplete.

Keep changes focused and reuse existing VUnit tools, APIs, and verification skills rather than implementing parallel functionality.