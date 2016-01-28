## Running a test case in the ModelSim GUI
Sometimes the textual error messages and logs are not enough to pinpoint the error and a test case needs to be opened in the GUI for visual debugging using single stepping, breakpoints and wave form viewing. VUnit makes it easy to open a test case in the GUI by having a `--gui={load,run}` command line flag:
```console
> python run.py --gui my_test_case
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
When running large designs this mode can be quite slow and it might be better to just do `--gui` and manually add a few signals of interest.

## GHDL - Viewing signals in GTKWave
Signals can be viewed in GTKWave when using the GHDL simulator and GTKWave executable is found in the `PATH` environment variable.
The `--gtkwave={vcd,ghw}` flag is used to select the file format to use.
The `--gtkwave-args` flag can be used to pass additional arguments to GTKWave, remember to wrap them in double quotes (`""`).

## Ctrl-C when using Git/MSYS Bash on Windows
VUnit will catch Ctrl-C and perform a clean shutdown closing all started simulation processes and printing the test report so far. On Git/MSYS Bash on Windows however there is a mechanism that hard kills a process a very short time after pressing Ctrl-C often prohibiting VUnit from completing its shutdown. This can leave simulation process open which have to be manually killed. See this [stack overflow post](http://stackoverflow.com/questions/23678045/control-c-kills-ipython-in-git-bash-on-windows-7) for tips on how to remove this mechanism.

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
