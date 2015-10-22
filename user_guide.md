# VUnit User Guide

## Introduction
The idea in VUnit is to have a single point of entry for compiling and running all tests within a VHDL project. Tests do not need to be manually added to some list as they are automatically detected. There is no need for maintaining a list of files in compile order or manually re-compile selected files after they have been edited as VUnit automatically determines the compile order as well as which files to incrementally re-compile. This is achieved by having a `run.py` file for each project where libraries are defined into which files are added using the VUnit Python interface. The `run.py` file then acts as a command line utility for compiling and running tests within the VHDL project.

## Python Interface

The public interface of VUnit is exposed through the `VUnit` class
that can be imported directly from the vunit module. Read [this](#installing-vunit) to make VUnit visible to Python.

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

```console
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
  --exit-0              Exit with code 0 even if a test failed. Still exits
                        with code 1 on fatal errors such as compilation
                        failure
  -v, --verbose         Print test output immediately and not only when
                        failure
  --no-color            Do not color output
  --gui {load,run}      Open test case(s) in simulator gui. 'load' only loads
                        the test case and gives the user control. 'run' loads
                        and runs the test case while recursively logging all
                        variables and signals
  --log-level {info,error,warning,debug}
  -p NUM_THREADS, --num-threads NUM_THREADS
                        Number of tests to run in parallel. Test output is not
                        continuously written in verbose mode with p > 1

activehdl:
  Aldec Active HDL specific flags

  --gui                 Open test case(s) in simulator gui with top level pre
                        loaded

rivierapro:
  Aldec Riviera Pro specific flags

  --gui                 Open test case(s) in simulator gui with top level pre
                        loaded

ghdl:
  GHDL specific flags

  --gtkwave {vcd,ghw}   Save .vcd or .ghw and open in gtkwave
  --gtkwave-args GTKWAVE_ARGS
                        Arguments to pass to gtkwave

modelsim:
  ModelSim specific flags

  --gui {load,run}      Open test case(s) in simulator gui. 'load' only loads
                        the test case and gives the user control. 'run' loads
                        and runs the test case while recursively logging all
                        variables and signals
  --new-vsim            Do not re-use the same vsim process for running
                        different test cases (slower)
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
bench that are each run in individual simulations. Putting multiple
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
```console
> python run.py -v lib.tb_example*
Running test: lib.tb_example
Running test: lib.tb_example_many.test_pass
Running test: lib.tb_example_many.test_fail
Running 3 tests

running lib.tb_example
Hello World!
pass (P=1 S=0 F=0 T=3) lib.tb_example (0.1 seconds)

running lib.tb_example.test_pass
This will pass
pass (P=2 S=0 F=0 T=3) lib.tb_example_many.test_pass (0.1 seconds)

running lib.tb_example.test_fail
Error: It fails
fail (P=2 S=0 F=1 T=3) lib.tb_example_many.test_fail (0.1 seconds)

==== Summary =========================================
pass lib.tb_example                (0.1 seconds)
pass lib.tb_example_many.test_pass (0.1 seconds)
fail lib.tb_example_many.test_fail (0.1 seconds)
======================================================
pass 2 of 3
fail 1 of 3
======================================================
Total time was 0.3 seconds
Elapsed time was 0.3 seconds
======================================================
Some failed!
```

The above example code can be found in [examples/vhdl/user_guide/](examples/vhdl/user_guide/).

# VUnit Checks
The above examples used the VHDL `assert` statement for self-checking. Vunit also provides a more complete assertion library described in the [Check User Guide](vunit/vhdl/check/user_guide.md).

# More examples
There are many examples demonstrating more specific usage of VUnit listed below:
* [examples/vhdl/user_guide/](examples/vhdl/user_guide/)
  * The most minimal VUnit project covering the basics of this user guide.

* [examples/vhdl/uart/](examples/vhdl/uart/)
  * A more realistic test bench of an UART to show VUnit usage on a typical module.
  In addition to the normal [run.py](examples/vhdl/uart/run.py) it also contains a [run_with_preprocessing.py](examples/vhdl/uart/run_with_preprocessing.py) to demonstrate the benefit of    location and check preprocessing.

* [examples/vhdl/check/](examples/vhdl/check/)
  * Demonstrates VUnit check subprograms.

* [examples/vhdl/array/](examples/vhdl/array/)
  * Demonstrates the `array_t` data type of [array_pkg](vunit/vhdl/array/src/array_pkg.vhd) which can be used to handle dynamically sized 1D, 2D and 3D data as well as storing and loading it from csv and raw files.

* [generate_tests](examples/vhdl/generate_tests)
  * Demonstrates generating multiple test runs of the same test bench with different generic values.

* [vivado](examples/vhdl/vivado)
  * Demonstrates compiling and performing behavioral simulation of Vivado IPs with VUnit.

* [com](examples/vhdl/com)
  * Demonstrates the `com` message passing package which can be used to communicate arbitrary objects between processes. Further reading can be found in the [com user guide](vunit/vhdl/com/user_guide.md)

* [examples/vhdl/logging/](examples/vhdl/logging/)
  * Demonstrates VUnit's support for logging.


## Selecting simulator backend
VUnit automatically detects which simulators are available on the `PATH` environment variable and by default selects the first one found. For people who have multiple simulators installed the `VUNIT_SIMULATOR` environment variable can be set to either `activehdl`,  `rivierapro`, `ghdl` or `modelsim` to explicitly choose the simulator backend.

## Interfacing with pre-compiled libraries
The `add_library` method of the VUnit class is intended for libraries managed by VUnit.
When interfacing with pre-compiled libraries such as `unisim` from Xilinx the `add_external_library` method can be used. Unlike the `add_library` method which only takes a logical library name for which VUnit will manage the compile location the `add_external_library` method also takes a search path to the pre-compiled library. External libraries are treated as black-boxes by VUnit and no dependency scanning will be performed.

## Running a test case in the ModelSim GUI
Sometimes the textual error messages and logs are not enough to pinpoint the error and a test case needs to be opened in the GUI for visual debugging using single stepping, breakpoints and wave form viewing. VUnit makes it easy to open a test case in the GUI by having a `--gui={load,run}` command line flag:
```console
> python run.py --gui=load my_test_case
```
This launches a GUI window for each test case with specific functions pre-loaded printing the following help:
```tcl
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
## Setting custom simulation options
Custom simulation options can be set using the`sim_options(name, value)` method. Options can either be set globally, for a library, for an entity or for a specific test.
```python
vu.set_sim_option("vsim_extra_args.gui", "-voptargs=+acc")
```

### Known simulation options
* `vsim_extra_args`
  - Extra arguments passed to `vsim` when loading the design.
* `vsim_extra_args.gui`
  - Extra arguments passed to `vsim` when loading the design in GUI mode where it takes precedence over `vsim_extra_args`.

## Ctrl-C when using Git/MSYS Bash on Windows
VUnit will catch Ctrl-C and perform a clean shutdown closing all started simulation processes and printing the test report so far. On Git/MSYS Bash on Windows however there is a mechanism that hard kills a process a very short time after pressing Ctrl-C often prohibiting VUnit from completing its shutdown. This can leave simulation process open which have to be manually killed. See this [stack overflow post](http://stackoverflow.com/questions/23678045/control-c-kills-ipython-in-git-bash-on-windows-7) for tips on how to remove this mechanism.

## Installing VUnit
To be able to import VUnit in your `run.py` script you need to make it visible to Python or else the following error occurs:
```console
Traceback (most recent call last):
   File "run.py", line 2, in <module>
     from vunit import VUnit
ImportError: No module named vunit
```

There are three methods to make VUnit importable in your `run.py` script:

1. Install it in your Python environment using `python setup.py install`
2. Set the `PYTHONPATH` environment variable to include the path to the VUnit root directory containing this user guide. Note that you shouldn't point to the vunit directory within the root directory.

3. Add a `import sys; sys.path.append("/path/to/vunit_root/")` statement in your `run.py` file **before** the `import vunit` statement.

## Creating Sigasi Projects
The official Sigasi [SigasiProjectCreator](https://github.com/sigasi/SigasiProjectCreator) utility can be used to generate a Sigasi project from a VUnit project using the following script. The script will create virtual folders for each VHDL library containing the files of the library.
```python
from SigasiProjectCreator import SigasiProjectCreator
from os.path import relpath, exists, basename
import os
from shutil import rmtree

def create_sigasi_project(prj, name, project_path):
    """
    Create Sigasi project from VUnit object prj with name into project_path
    """
    creator = SigasiProjectCreator(name, 2008)

    for source_file in prj.get_project_compile_order():
        file_name = source_file.name
        library_name = source_file.library.name
        virtual_name = library_name + "/" + basename(file_name)
        creator.add_link(virtual_name, file_name)
        creator.add_mapping(virtual_name, library_name)

    if not exists(project_path):
      os.makedirs(project_path)

    creator.write(project_path)

```
