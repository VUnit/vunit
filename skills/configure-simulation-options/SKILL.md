---
name: configure-simulation-options
description: Configure VUnit simulation behavior using portable and simulator-specific options. Use when adjusting assertion handling, simulator flags, coverage collection, waveform viewing, or other simulation settings for projects, testbenches, tests, or individual configurations.
license: MPL-2.0
---

# Configure Simulation Options with VUnit

1. **Use VUnit's simulation options.** Configure simulation behavior through VUnit's Python API rather than invoking simulators directly or modifying generated simulator scripts. Consult the supported simulation options before selecting an option and its value.

2. **Choose the appropriate scope.** Use `set_sim_option` at the project, library, testbench, or test level depending on which simulations need the setting. Use the `sim_options` argument to `add_config` when individual named configurations require different settings.

   For example, configure assertion handling for a testbench:

   ```python
   tb = lib.test_bench("tb_example")
   tb.set_sim_option("vhdl_assert_stop_level", "warning")
   ```

   To configure an individual test:

   ```python
   test = tb.test("protocol checks")
   test.set_sim_option("vhdl_assert_stop_level", "warning")
   ```

   Or create a named configuration with specific simulation settings:

   ```python
   test.add_config(
       name="strict",
       sim_options=dict(vhdl_assert_stop_level="warning"),
   )
   ```

   Do not introduce named configurations merely to apply a setting that can be applied directly.

3. **Prefer portable options when available.** VUnit provides simulator-independent options such as `vhdl_assert_stop_level`, `disable_ieee_warnings`, and `enable_coverage`. Prefer these over equivalent simulator-specific flags when they meet the requirement.

   Some settings affect how failures are detected. For example, `vhdl_assert_stop_level` determines which VHDL assertion severities stop simulation and takes precedence over the `fail_on_warning` attribute. Do not suppress warnings or errors merely to make failing tests pass.

4. **Use simulator-specific options when necessary.** VUnit supports simulator-specific flags and initialization files for capabilities that differ between simulators.

   For example:

   ```python
   if vu.get_simulator_name() == "ghdl":
       tb.set_sim_option("ghdl.sim_flags", ["--stats"])
   ```

   Verify option names, supported values, and simulator compatibility against the installed VUnit version and simulator documentation. Follow existing project conventions and avoid introducing simulator dependencies when portable alternatives are available.

   Some options accept lists of flags. When extending an existing list-valued option, `set_sim_option` supports `overwrite=False` to append rather than replace its existing value.

5. **Distinguish simulation and compilation options.** Simulation options affect test execution and can be configured for individual tests or configurations. Compilation options apply to HDL source files and are configured through VUnit's compilation-option API.

   Some capabilities, notably code coverage, may require both simulation and compilation settings. Use the appropriate API for each stage rather than treating compilation flags as per-test simulation options.

   Consult the VUnit coverage example when configuring coverage collection.

6. **Validate the configuration.** Run the affected tests and confirm that the intended simulation behavior is active. Check that settings applied at a broad scope do not unintentionally affect unrelated tests.

   For interactive debugging, prefer existing VUnit command-line options such as `--gui` and waveform-viewer options when they satisfy the need. Do not permanently modify project configuration for a temporary debugging session.

   Keep simulator-specific configuration focused and avoid implementing custom simulator invocation infrastructure.

## Documentation

Prefer locally available VUnit documentation when working offline. Online references:

- [VUnit Simulation Options](https://vunit.github.io/py/opts.html#simulation-options)
- [VUnit Compilation Options](https://vunit.github.io/py/opts.html#compilation-options)
- [VUnit Python API](https://vunit.github.io/py/vunit.html)
- [VUnit Command Line Interface](https://vunit.github.io/cli.html)
- [VUnit Coverage Example](https://github.com/VUnit/vunit/tree/master/examples/vhdl/coverage)