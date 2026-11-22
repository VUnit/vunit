---
name: configure-hdl-parameters
description: Configure VHDL generics and Verilog parameters in VUnit tests. Use when verifying parameterized HDL designs, testing different widths, depths, or operating modes, or exploring parameter boundary conditions without duplicating testbenches.
license: MPL-2.0
---

# Configure HDL Parameters with VUnit

1. **Reuse verification logic.** When the same functionality must be verified with different HDL parameter values, use VUnit configurations rather than duplicating testbenches, tests, or run scripts. Choose parameter combinations that exercise meaningful behaviors and boundary conditions.

2. **Use VUnit's configuration API.** Configure VHDL generics or Verilog parameters through the Python API in `run.py`. Use `set_generic` or `set_parameter` to set values across existing configurations, and `add_config` to create named variants.

   For example, test a streaming buffer with several depths:

   ```python
   tb = lib.test_bench("tb_stream_buffer")

   for depth in [1, 3, 8]:
       tb.add_config(
           name=f"depth={depth}",
           generics=dict(depth=depth),
       )
   ```

   For Verilog, use `parameters` instead of `generics`.

3. **Understand configuration inheritance.** VUnit initially creates an unnamed default configuration. Named configurations created using `add_config` inherit its settings, with explicitly supplied values overriding the inherited ones. Once named configurations exist, the unnamed default is no longer executed separately.

   For example:

   ```python
   tb.set_generic("data_width", 8)

   for depth in [1, 3, 8]:
       tb.add_config(
           name=f"depth={depth}",
           generics=dict(depth=depth),
       )
   ```

   All three configurations use `data_width = 8`. The `set_generic` method also updates existing named configurations, so be mindful of call order when combining common and variant-specific settings.

4. **Choose the appropriate scope.** Apply configurations at the testbench level when all tests should use the same parameter variations. Apply configurations to individual tests when only particular tests need them.

   ```python
   test = tb.test("wraparound")

   test.add_config(
       name="small width",
       generics=dict(data_width=4),
   )
   ```

   When `run_all_in_same_sim` is enabled, use testbench-level configurations because the tests share a simulation.

5. **Select meaningful parameter values.** Consider boundary conditions, minimum supported sizes, non-power-of-two dimensions, and combinations that exercise distinct behavior. Avoid unnecessary Cartesian products.

   Ensure that the testbench exposes and forwards the relevant generics or parameters to the DUT. Reference models and checks must account for the selected values rather than assuming one fixed configuration.

6. **Validate the variants.** List the discovered tests to confirm that the intended configurations exist, then execute them:

   ```bash
   python run.py --list
   python run.py
   ```

   Use descriptive configuration names that make failing parameter combinations easy to identify.

## Documentation

Online references:

- [VUnit Python Interface — Configurations](https://vunit.github.io/py/ui.html#configurations)
- [VUnit Python API — TestBench and Test](https://vunit.github.io/py/vunit.html)
- [VUnit generate_tests Example](https://github.com/VUnit/vunit/tree/master/examples/vhdl/generate_tests)
- [Handling Complex Top-Level Generics](https://vunit.github.io/blog/2017_06_03_enable_your_simulator_to_handle_complex_top_level_generics.html)