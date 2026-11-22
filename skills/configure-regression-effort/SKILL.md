---
name: configure-regression-effort
description: Control verification workload and execution time using VUnit configurations and attributes. Use when creating fast development regressions, more thorough verification runs, or improving the efficiency of long-running and randomized tests.
license: MPL-2.0
---

# Configure Regression Effort with VUnit

1. **Adapt verification effort to the task.** Tests used during development should provide useful feedback quickly, while more thorough regressions may perform additional verification. Where appropriate, make workload parameters such as transaction counts, dataset sizes, or simulation duration configurable. Do not reduce verification effort so far that important functionality is no longer exercised.

2. **Use VUnit configurations for different workloads.** Reuse the same verification logic with different effort levels rather than duplicating tests or run scripts.

   For example, a randomized streaming testbench can expose a `NUM_TRANSACTIONS` generic:

   ```python
   test = lib.test_bench("tb_stream_buffer").test("random traffic")

   test.add_config(
       name="quick",
       generics={"NUM_TRANSACTIONS": 100},
       attributes={".smoke_test": None},
   )

   test.add_config(
       name="thorough",
       generics={"NUM_TRANSACTIONS": 100000},
       attributes={".long_test": None},
   )
   ```

   These attributes are user-defined labels, not special VUnit execution modes. Choose workload sizes and attribute names appropriate for the project.

3. **Select workloads using attributes.** Use VUnit's existing attribute filtering to select appropriate tests and configurations.

   For example:

   ```bash
   # Exclude long-running configurations during development.
   python run.py --without-attributes=.long_test

   # Run the complete regression.
   python run.py

   # Run only configurations marked as long tests.
   python run.py --with-attributes=.long_test
   ```

   Prefer the existing filtering mechanisms over implementing custom suite selection or command-line options.

4. **Improve efficiency of long tests.** Consider splitting long tests into smaller, independently executable tests or configurations when doing so improves feedback or parallel execution.

   For randomized tests, several shorter configurations can explore different random sequences using VUnit-generated seeds. Follow the `randomization` skill for seed management and failure reproduction.

   Use VUnit's existing parallel execution support (`-p`) and scheduling facilities rather than implementing a custom scheduler.

   Splitting tests introduces additional simulator startup overhead. It is useful when the benefits of independent execution and load balancing outweigh that cost. Do not assume that multiple shorter randomized runs provide identical coverage to one longer run.

5. **Preserve meaningful verification.** Choose effort levels based on the design's requirements and observed execution times. Keep essential directed and boundary-condition verification available during development. Do not use short configurations as a substitute for thorough verification when additional coverage is required.

6. **Validate and refine.** List the available tests and configurations, verify that attribute filtering selects the intended workloads, and run them. Compare execution times when optimizing long regressions. Keep configuration code simple and avoid unnecessary workload variants.

## Documentation

Online references:

- [VUnit Python Interface — Configurations](https://vunit.github.io/py/ui.html#configurations)
- [VUnit Python Interface — Attributes](https://vunit.github.io/py/ui.html#attributes)
- [VUnit Command Line Interface](https://vunit.github.io/cli.html)
- [Efficient Testing with VUnit – Part 2: Optimizing Long Tests](https://www.linkedin.com/pulse/efficient-testing-vunit-part-2-optimizing-long-tests-lars-asplund-dmzmf)