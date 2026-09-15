# AGENTS.md

Guidance for AI coding agents working on the VUnit repository.

To *use* VUnit rather than develop it, read the [documentation](https://vunit.github.io) and the machine-readable
[VHDL API](https://vunit.github.io/api/vunit_lib.json) and [Python API](https://vunit.github.io/api/python.json).

## Repository layout

- `vunit/`: the Python package, with the run script API in `vunit/ui/`, the simulator interfaces in `vunit/sim_if/` and the test runner in `vunit/test/`.
- `vunit/vhdl/`: the VHDL libraries compiled into `vunit_lib` (`run`, `check`, `logging`, `com`, `data_types`, `verification_components`, ...). `vunit/vhdl/osvvm` is a third-party git submodule.
- `vunit/verilog/`: the SystemVerilog support.
- `tests/unit/`, `tests/acceptance/`, `tests/lint/`: see "Testing" in `docs/contributing.rst`.
- `examples/`, `docs/` (Sphinx) and `tools/` (documentation and release scripts).

## Commands

- **Unit tests:** `pytest tests/unit/`, or `tox -e py313-unit`.
- **Lint** (pycodestyle, pylint, mypy, license headers): `tox -e py313-lint`.
- **Formatting:** black, with the line length from `pyproject.toml`. Check only the files you changed, e.g. `python -m black --check <files>`. `tox -e py313-fmt` formats every file in the repository.
- **Acceptance tests with a simulator:** `tox -e py313-acceptance-<simulator>`, where `<simulator>` is `activehdl`, `ghdl`, `modelsim`, `nvc` or `rivierapro`.
- **Verification components:** `tox -e py313-vcomponents-<simulator>`.
- **Documentation:** `tox -e py313-docs`.
  - The build needs the git tags for the release notes.
  - It needs GHDL for the API reference. Set `VUNIT_DOCS_SKIP_API=1` to build without it.
- **All tox environments:** `tox -l`.

## Rules

Details are in `docs/contributing.rst`.

- **News fragments:** a change visible to users needs a news fragment `docs/news.d/<issue or pull request number>.<type>.rst`. `<type>` is one of `breaking`, `bugfix`, `doc`, `deprecation`, `feature` or `misc`.
- **License header:** Python, VHDL and Verilog source files start with the Mozilla Public License 2.0 header with the copyright assigned to Lars Asplund. Copy it from a file next to the new one. `tests/lint/test_license.py` checks it.
- **Tests:** new functionality comes with tests.

## Generated files

Change the generator and run it again instead of editing its output by hand:

- `vunit/vhdl/check/tools/generate_check_equal.py`, `generate_check_equal_2008p.py` and `generate_check_match.py` generate parts of `vunit/vhdl/check/src/check_api*.vhd` and `check*.vhd`, and their testbenches.
- `vunit/vhdl/data_types/tools/generate_dict.py` generates the typed `set_*`/`get_*` subprograms and their aliases in `dict_pkg`.

## Pitfalls

- Running a `run.py` inside the repository creates a `vunit_out/` directory next to it. Do not commit it.
