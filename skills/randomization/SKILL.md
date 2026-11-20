---
name: randomization
description: Use reproducible randomization in VUnit VHDL testbenches. Use when generating randomized stimulus, initializing random number generators, managing independent random streams, or reproducing failures caused by randomized tests. Supports standard ieee.math_real.uniform and commonly used randomization libraries.
license: MPL-2.0
---

# Randomization with VUnit

1. **Use VUnit-generated seeds.** VUnit automatically generates a new base seed for each simulation. Use this seed to initialize random number generators rather than creating custom seeds from simulation time, fixed constants, or other sources. This provides variation between runs while retaining reproducibility.

2. **Remain independent of the randomization library.** VUnit manages seed generation independently of the library used to generate random values. Use the appropriate VUnit `get_seed` function or procedure and adapt its result to the selected randomization library. Do not require a particular randomization framework.

   For example, obtain a seed using the testbench's `runner_cfg` generic:

   ```vhdl
   constant seed : string := get_seed(runner_cfg);
   ```

   VUnit also provides integer, signed, unsigned, and string seed variants, as well as a procedure specifically for `ieee.math_real.uniform`:

   ```vhdl
   get_uniform_seed(seed1, seed2, "stimulus");
   uniform(seed1, seed2, random_value);
   ```

3. **Derive independent seeds when needed.** When multiple random number generators are used, derive their seeds from VUnit's base seed using distinct salts:

   ```vhdl
   constant producer_seed : string := get_seed(runner_cfg, "producer");
   constant consumer_seed : string := get_seed(runner_cfg, "consumer");
   ```

   Use stable, meaningful salts to keep random streams independent and reproducible. A process's `'path_name` can also serve as a salt when appropriate.

   Processes without access to `runner_cfg` can use VUnit's seed procedures, which wait for `test_runner_setup` to complete if necessary.

4. **Reproduce randomized failures.** When a randomized test fails, preserve its seed. After making changes to address the failure, rerun the affected test using the same seed to verify that the changes resolve the original problem.

   VUnit provides two ways to repeat seeds:

   **Repeat seeds from local test history:**

   ```bash
   python run.py --seed repeat
   ```

   This repeats each test's previously recorded seed, using test history stored locally in VUnit's output directory. Different tests can therefore retain different seeds.

   **Specify an explicit seed:**

   ```bash
   python run.py "lib.tb_example.random test" --seed 8c5c0ea80b58a8ee
   ```

   An explicit seed applies the same base seed to every selected test. This is useful when reproducing an individual failing test, particularly one that failed on CI.

   The seed used by each test is recorded in its simulation output and displayed in the console output when a test fails.

   Be aware that:

   - `--seed repeat` uses the test history on the machine executing the command, not history from another machine.
   - `--clean` removes locally stored test history.
   - If no previous seed is recorded for a test, `repeat` generates a new seed.
   - Tests executed within the same simulation share a base seed.

   Do not assume that `--seed repeat` reproduces a CI failure unless the corresponding CI test history has been imported.

5. **Transfer test history between machines when needed.** To repeat several CI tests locally with their individual seeds, export the CI test history and import it into the local VUnit project.

   VUnit provides `export_items` and `import_items` for this purpose.

   For example, the CI run script can export test history after execution using a `post_run` callback:

   ```python
   def export_history(results):
       vu.export_items(["test_history"], "ci-test-history")

   vu.main(post_run=export_history)
   ```

   The `results` argument is required by the callback interface but is not needed for this example.

   Preserve the exported directory as a CI artifact and transfer it to the local machine. The export directory must be dedicated to this purpose because VUnit clears it when exporting.

   Locally, import the history before executing the tests:

   ```python
   vu.import_items("ci-test-history")
   vu.main()
   ```

   Adapt these examples to the existing run script, preserving any existing callbacks or custom command-line options. Import history only when requested, rather than unconditionally replacing local history.

   After importing the CI history, run:

   ```bash
   python run.py --seed repeat
   ```

   VUnit will then use the imported seeds for the corresponding tests. Ensure the test names and configurations match those in the exported history.

   Consult the VUnit Python API documentation for `export_items` and `import_items` when implementing this workflow.

6. **Preserve reproducibility while debugging.** Keep using the original failing seed throughout debugging and subsequent fixes until the test passes. Once the failure is resolved, run additional simulations with automatically generated seeds to explore other scenarios.

   Reusing a seed reproduces the random sequence only when the randomization algorithm and relevant sequence of random-number requests remain unchanged. If testbench changes alter those requests, the generated stimulus may differ.

## Documentation

Online references:

- [Run Library User Guide — Seeds for Random Number Generation](https://vunit.github.io/run/user_guide.html#seeds-for-random-number-generation)
- [VUnit Command Line Interface](https://vunit.github.io/cli.html)
- [VUnit Python API — export_items and import_items](https://vunit.github.io/py/vunit.html)
- [Efficient Testing with VUnit — Test History Export/Import](https://www.linkedin.com/pulse/efficient-testing-vunit-test-selection-prioritization-lars-asplund-sivwf)