# VUnit User Guide

## Introduction
The idea in VUnit is to have a single point of entry for compiling and running all tests within a VHDL project. Tests do not need to be manually added to some list as they are automatically detected. There is no need for maintaining a list of files in compile order or manually re-compile selected files after they have been edited as VUnit automatically determines the compile order as well as which files to incrementally re-compile. This is achieved by having a `run.py` file for each project where libraries are defined into which files are added using the VUnit Python interface. The `run.py` file then acts as a command line utility for compiling and running tests within the VHDL project.

## Python Interface

The public interface of VUnit is exposed through the `VUnit` class
that can be imported directly from the vunit module.

```python
# file: run.py
from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory
lib.add_source_files("*.vhd")

# Run vunit function
vu.main()
```

A `VUnit` object can be created from command line arguments by using
the `from_argv` method effectively creating a custom command line tool
for running tests in the user project.  Source files and libraries are
added to the project by using methods on the VUnit object. The
configuration is followed by a call to the `main` method which will
execute the function specified by the command line arguments and exit
the script. The added source files are automatically scanned for test
cases.

```
> python run.py -h
usage: run.py [-h] [-l] [--compile] [--elaborate] [--clean] [-o OUTPUT_PATH]
              [-x XUNIT_XML] [-v] [--no-color] [--gui {load,run}]
              [--log-level {info,error,warning,debug}]
              [--gui {load,run}] [--new-vsim]
              [tests [tests ...]]

VUnit command line tool.

positional arguments:
  tests                 Tests to run

optional arguments:
  -h, --help            show this help message and exit
  -l, --list            Only list all test cases
  --compile             Only compile project without running tests
  --elaborate           Only elaborate test benches without running
  --clean               Remove output path first
  -o OUTPUT_PATH, --output-path OUTPUT_PATH
                        Output path for compilation and simulation artifacts
  -x XUNIT_XML, --xunit-xml XUNIT_XML
                        Xunit test report .xml file
  -v, --verbose         Print test output immediately and not only when
                        failure
  --no-color            Do not color output
  --gui {load,run}      Open test case(s) in simulator gui. 'load' only loads
                        the test case and gives the user control. 'run' loads
                        and runs the test case while recursively logging all
                        variables and signals
  --log-level {info,error,warning,debug}

modelsim:
  ModelSim specific flags

  --gui {load,run}      Open test case(s) in simulator gui. 'load' only loads
                        the test case and gives the user control. 'run' loads
                        and runs the test case while recursively logging all
                        variables and signals
  --new-vsim            Do not re-use the same vsim process for running
                        different test cases (slower)

ghdl:
  GHDL specific flags

  --gtkwave {vcd,ghw}   Save .vcd or .ghw and open in gtkwave
  --gtkwave-args GTKWAVE_ARGS
                        Arguments to pass to gtkwave
```

## VHDL Test Benches
In its simplest form a VUnit VHDL test bench looks like this:
```vhdl
-- file tb_example.vhd
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_example is
  generic (runner_cfg : runner_cfg_t);
end entity;

architecture tb of tb_example is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    report "Hello world!";
    test_runner_cleanup(runner); -- Simulation ends here
  end process;
end architecture;
```

From `tb_example.vhd` a single test case named `lib.tb_example` is
created.  It is also possible to put multiple tests in a single test
benche that are each run in individual simulations. Putting multiple
tests in the same test bench is a good way to share a common test
environment.

```vhdl
-- file tb_example_many.vhd
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_example_many is
  generic (runner_cfg : runner_cfg_t);
end entity;

architecture tb of tb_example_many is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      if run("test_pass") then
        report "This will pass";

      elsif run("test_fail") then
        assert false report "It fails";

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
```

From `tb_example_many.vhd` two test cases named
`lib.tb_example_many.test_pass` and `tb_example_many.test_fail` are
created.

We can run these test using `run.py` command line interface:
```
> python run.py -v lib.tb_example*
Running test: lib.tb_example
Running test: lib.tb_example_many.test_pass
Running test: lib.tb_example_many.test_fail
Running 3 tests
running lib.tb_example
Hello World!
pass (P=1 F=0 T=3) lib.tb_example

running lib.tb_example.test_pass
This will pass
pass (P=2 F=0 T=3) lib.tb_example_many.test_pass

running lib.tb_example.test_fail
Error: It fails
fail (P=2 F=1 T=3) lib.tb_example_many.test_fail

pass lib.tb_example after 0.1 seconds
pass lib.tb_example_many.test_pass after 0.1 seconds
fail lib.tb_example_many.test_fail after 0.1 seconds

Total time 0.3 seconds
2 of 3 passed
Some failed!
```

The above example code can be found in `examples/user_guide/`.

# More examples
There are many examples demonstrating more specific usage of VUnit listed below:
* [examples/user_guide/](examples/user_guide/)
  * The most minimal VUnit project covering the basics of this user guide.

* [examples/uart/](examples/uart/)
  * A more realistic test bench of an UART to show VUnit usage on a typical module.
  In addition to the normal [run.py](examples/uart/run.py) it also contains a [run_with_preprocessing.py](examples/uart/run_with_preprocessing.py) to demonstrate the benefit of    location and check preprocessing.

* [examples/array/](examples/array/)
  * Demonstrates the `array_t` data type of [array_pkg](vhdl/array/src/array_pkg.vhd) which can be used to handle dynamically sized 1D, 2D and 3D data as well as storing and loading it from csv and raw files.

* [generate_tests](examples/generate_tests)
  * Demonstrates generating multiple test runs of the same test bench with different generic values.

* [vivado](examples/vivado)
  * Demonstrates compiling and performing behavioral simulation of Vivado IPs with VUnit.

* [com](examples/com)
  * Demonstrates the `com` message passing package which can be used to communicate arbitrary objects between processes. Further reading can be found in the [com user guide](vhdl/com/user_guide.md)

## Interfacing with pre-compiled libraries
The `add_library` method of the VUnit class is intended for libraries managed by VUnit.
When interfacing with pre-compiled libraries such as `unisim` from Xilinx the `add_external_library` method can be used. Unlike the `add_library` method which only takes a logical library name for which VUnit will manage the compile location the `add_external_library` method also takes a search path to the pre-compiled library. External libraries are treated as black-boxes by VUnit and no dependency scanning will be performed.

## Running a test case in the ModelSim GUI
Sometimes the textual error messages and logs are not enough to pinpoint the error and a test case needs to be opened in the GUI for visual debugging using single stepping, breakpoints and wave form viewing. VUnit makes it easy to open a test case in the GUI by having a `--gui={load,run}` command line flag:
```
> python run.py --gui=load my_test_case
```
This launches a GUI window for each test case with specific functions pre-loaded printing the following help:
```
# List of VUnit modelsim commands:
# vunit_help
#   - Prints this help
# vunit_load [vsim_extra_args]
#   - Load design with correct generics for the test
#   - Optional first argument are passed as extra flags to vsim
# vunit_run
#   - Run test, must do vunit_load first
```

The test bench will then already have been loaded using the `vunit_load` command. This only has to be done once to select the test bench as the top level entity for simulation. After this breakpoints can be set and signals added to the log or to the waveform viewer manually by the user. The test case is then run using the `vunit_run` command. Recompilation can be performed without closing the GUI by running `run.py` with the `--compile` flag in a separate terminal. To re-run the test after compilation:
```tcl
restart -f
vunit_run
```

It is also possible to automatically run the test case in the gui while logging all signals and variables recursively using the `--gui=run` flag.
After simulation the user can manually add objects of interest to the waveform viewer without re-running since everything has been logged.
When running large designs this mode can be quite slow and it might be better to just do `--gui=load` and manually add a few signals of interest.

## GHDL - Viewing signals in GTKWave
Signals can be viewed in GTKWave when using the GHDL simulator and GTKWave executable is found in the `PATH` environment variable.
The `--gtkwave={vcd,ghw}` flag is used to select the file format to use.
The `--gtkwave-args` flag can be used to pass additional arguments to GTKWave, remember to wrap them in double quotes (`""`).

## Disabling warnings from IEEE packages
Warnings from IEEE packages can be disabled in `run.py`:
```python
# They can be lobally disabled...
vu.disable_ieee_warnings()

# ... or just disabled for a library
lib = vu.lib("lib")
lib.disable_ieee_warnings()

# ... or just disabled for a test bench
ent = lib.entity("ent")
ent.disable_ieee_warnings()

# ... or just disabled for a test case
test = ent.test("test")
test.disable_ieee_warnings()
```
