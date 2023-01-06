
.. _release_notes:

Release notes
=============

Versions follow `Semantic Versioning <https://semver.org/>`_ (``<major>.<minor>.<patch>``).

Backward incompatible (breaking) changes will only be introduced in major versions
with advance notice in the **Deprecations** section of releases.

.. NOTE:: For installation instructions, read :ref:`this <installing>`.

.. towncrier-draft-entries:: UNRELEASED

..
   Do *NOT* add changelog entries here! This file is managed by towncrier. You *may*
   edit previous change logs for corrections, typos, etc.

   To add a new entry, please reference https://vunit.github.io/contributing.html
   and note that the news folder is named changelog.d

.. _latest_release:

.. towncrier release notes start

:vunit_commit:`4.6.0 <v4.6.0>` - 2021-10-25 (latest)
----------------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.6.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.5.0...v4.6.0>`__

- Add Python 3.9 and 3.10 to classifiers.
- Use MAJOR and MINOR constants to check supported Python version. :vunit_issue:`724`
- Fix pylint issues.
- Use f-strings for string formatting. :vunit_issue:`743` :vunit_issue:`747`
- Specify encoding when using 'open'. :vunit_issue:`748`
- Set black line-length to 120 characters. :vunit_issue:`736`
- Use Path from pathlib, instead of `open()`.
- Add support for log location based on VHDL-2019 call paths. :vunit_issue:`729`
- GHDL supports VHDL package generics. :vunit_issue:`753`
- Bump OSVVM to 2021.09.
- [Tox] Use pytest for collecting coverage, add py310.
- [Tests] mark array_axis_vcs and verilog_ams examples as xfail. :vunit_issue:`751`
- [Logging/log_deprecated_pkg] fix compilation issues with Cadence tools. :vunit_issue:`731`
- [Parsing/tokenizer] partial revert of 5141f7c :vunit_issue:`735` :vunit_issue:`745`
- [UI] make glob search recursive by default.
- [VCs] bugfix AXI stream slave nonblocking check. :vunit_issue:`720`
- [Examples] add shebang to run scripts. :vunit_issue:`738`
- [Example/vhdl/user_guide] add VHDL 1993 variant, clean use statements, skip in acceptance tests if VHDL context not supported. :vunit_issue:`737`
- [Examples/vhdl/array_axis_vcs] Fix PSL check for valid fifo in data during write. :vunit_issue:`750` :vunit_issue:`766`
- [Docs] bump sphinx_btd_theme to v1, revert temporary pinning of Sphinx and docutils, remove redundant delete message call from com user guide example, fix ref to Travis CI (deprecated) (GitHub Actions is used now), add section about envvars, document VUNIT_VHDL_STANDARD, use 'exec' directive to generate content in examples, update 'Credits and License', add refs to Tratex. :vunit_issue:`730` :vunit_issue:`739` :vunit_issue:`761`
- [CI] add emojis/icons, avoid deployments from forks, fix deploy condition event, add job using setup-ghdl-ci, update images from Debian Buster to Debian Bullseye, do not overload image tags.

:vunit_commit:`4.5.0 <v4.5.0>` - 2021-05-21
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.5.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.4.0...v4.5.0>`__

- Update year and update license test to 2021.
- Bump OSVVM. :vunit_issue:`712`
- Support Python 3.9.
- Call `supports_coverage()` rather than returning method object. :vunit_issue:`638`
- Do not use `relpath` when printing output file. :vunit_issue:`661`
- Make `runner.create_output_path` a member of `TestRunner` class and reanme to `_get_output_path`. :vunit_issue:`682`
- Update `check_stable` to handle longer time frames. :vunit_issue:`636`
- Add `check_equal` for `character`. :vunit_issue:`721` :vunit_issue:`722`
- Update `.gitignore`. :vunit_issue:`641`
- Resolve ambiguity between VUnit's `line_vector` type and the new standard `line_vector` type in VHDL-2019. :vunit_issue:`664`
- [Tests] Use `str` for params to `self.check`, reduce 'many_keys' to avoid failure with latest GHDL.
- [Docs] Travis is not used for releases, use `autodoc_default_options` instead of (deprecated) `autodoc_default_flags`, fix duplicated content and index of vunit_cli, add intersphinx mapping to docs.python.org, update 'Credits' and 'License', use buildthedocs/sphinx.theme, replace `LICENSE.txt` with `LICENSE.rst`, replace `README.rst` with `README.md`, move 'Requirements' from 'About' to 'Installing', add captioned toctrees, use admonitions, move CI out from CLI and update content, add blog post on continuous integration, clarify that GHDL is a rolling project. :vunit_issue:`694`
- [Tools] raise exception if git not available when creating release notes.
- [Example/vhdl/array_axis_vcs] Update, expand procedure `run_test`, add stall functionality. :vunit_issue:`648`
- [UI] Fix not serializable path when exporting JSON. :vunit_issue:`657`
- [Tox] add pyproject.toml, use isolated_build, merge tox.ini into pyproject.yml.
- [Setup] Ensure that the source tree is on the sys path.
- [RivieraPro] Fix coverage merge error. :vunit_issue:`675`
- [RivieraPro] handle empty macro. :vunit_issue:`681`
- [RivieraPro] Update VHDL version option in command line interface to work with version 2020.04 and above. :vunit_issue:`664`
- [VCs] Add null AXI stream master and slave constants.
- [VCs] Fix bug in AXI stream protocol checker rule 4.
- [VCs] Add ability to define the actor on new_axi_slave function. :vunit_issue:`709`
- [VCs] Push avalon master read req msg one cycle earlier. :vunit_issue:`695` :vunit_issue:`696`
- [VCs] Fix broken msg passing in wishbone master. :vunit_issue:`692` :vunit_issue:`693`
- [CI] Update container registry, use ghcr.io.
- [CI] Pin Sphinx and docutils version to work around theme issues.

:vunit_commit:`4.4.0 <v4.4.0>` - 2020-03-26
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.4.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.3.0...v4.4.0>`__

- Update year and update license test to 2020.
- Bump OSVVM to latest version.
- Add possibility to configure random stalls for AXI Stream. :vunit_issue:`557`
- JSON-for-VHDL: use base16 encodings. :vunit_issue:`595`
- First release requiring Python 3.6 or higher. Python 2.7, 3.4 and 3.5 are not supported anymore. :vunit_issue:`596` :vunit_issue:`601`
- Start adding type annotations to the Python sources; add mypy (a static type checker) to the list of linters. :vunit_issue:`601` :vunit_issue:`626`
- Move co-simulation (VHPIDIRECT) sources (implementation and example) to `VUnit/cosim <https://github.com/VUnit/cosim>`_. :vunit_issue:`606`
- ghdl interface: with ``ghdl_e``, save runtime args to JSON file. :vunit_issue:`606`
- Add missing mode assertions to ``-93`` sources of ``integer_vector_ptr`` and ``string_ptr``. :vunit_issue:`607`
- Add method ``get_simulator_name()`` to public Python API. :vunit_issue:`610`
- Start replacing ``join``, ``dirname``, etc. with ``pathlib``. :vunit_issue:`612` :vunit_issue:`626` :vunit_issue:`632`
- Fix parsing adjacent hyphens in a literal. :vunit_issue:`616`
- Fix ``ghdl.flags`` error in documentation. :vunit_issue:`620`
- Rename compile option ``ghdl.flags`` to ``ghdl.a_flags``. :vunit_issue:`624`
- Move ``project.Library`` to separate file.
- Remove Travis CI and AppVeyor, use GitHub Actions only.
- Remove Sphinx extension ABlog; handle posts as regular pages in subdir ``blog``.
- Update GHDL to v0.37 in Windows CI jobs.
- Fix regression in GHDL (``prefix of array attribute must be an object name``). :vunit_issue:`631` :vunit_issue:`635`
- Add code coverage support for GHDL. :vunit_issue:`627`

:vunit_commit:`4.3.0 <v4.3.0>` - 2019-11-30
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.3.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.2.0...v4.3.0>`__

- Fix broken ``vhdl_standard`` setting in some situations. :vunit_issue:`594`
- Add 'external modes' (VHPIDIRECT) to ``string_ptr`` and ``integer_vector_ptr``; add ``byte_vector_prt`` too. :vunit_issue:`507` :vunit_issue:`476`
- Add report data to ``Results`` object/class. :vunit_issue:`586`
- Use a Python formatter: `psf/black <https://github.com/psf/black>`_. :vunit_issue:`554`
- Refactor ``vunit/ui``, ``vunit/sim_if``, ``vunit/test`` and ``tests``. :vunit_issue:`572` :vunit_issue:`582`
- Deprecate ``array_pkg``. It will be removed in future releases. Use :ref:`integer_array_pkg` instead. :vunit_issue:`593`
- Python 3.4 reached End-of-life in 2019-03-18 and it is no longer tested. Support is expected to break in future releases.
- Add support for Python 3.8.
- Deprecate Python 2.7. This is the last release supporting Python 2 and Python 3. Upcoming releases will be for Python 3 only.

:vunit_commit:`4.2.0 <v4.2.0>` - 2019-10-12
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.2.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.1.0...v4.2.0>`__

- Add ``-m/--minimal`` flag to only compile what is necessary for selected tests.
- Fix axi_stream VC for 0-length tid/tdest/tuser.
- Fix work reference for non-lower case library names. :vunit_issue:`556`
- Add ``init_files.before_run`` hook to RivieraPRO and ModelSim.
- Do not add extra quotes when invoking a gtkwave subprocess. :vunit_issue:`563`

:vunit_commit:`4.1.0 <v4.1.0>` - 2019-09-29
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.1.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.8...v4.1.0>`__

- Enhancements to Stream VCI and AXI Stream VCs. (:vunit_issue:`420`, :vunit_issue:`422`, :vunit_issue:`429`, :vunit_issue:`483`)
- Add option 'overwrite' to set_sim_option. (:vunit_issue:`471`)
- ActiveHDL: add code coverage support. (:vunit_issue:`461`)
- GtkWave: add sim option 'ghdl.init_file.gui'. (:vunit_issue:`459`)
- GHDL: add boolean option ghdl.elab_e, to execute 'ghdl -e' only. (:vunit_issue:`467`)
- GHDL: with VHDL 2008 nonzero return values produce a fail. (:vunit_issue:`469`)
- Add experimental VHDL 2019 support. (:vunit_issue:`549`)

:vunit_commit:`4.0.8 <v4.0.8>` - 2018-12-04
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.8/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.7...v4.0.8>`__

- Fix vivado submodule missing from release. :vunit_issue:`415`
- Add support for checking AXI response in axi_lite_master
- Fix bug with coverage flag not working with unique-sim in rivierapro
- Support for Avalon-MM burst transfers
- Unsure LICENSE_QUEUE environment variable is in effect for RivieraPRO

:vunit_commit:`4.0.7 <v4.0.7>` - 2018-11-20
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.7/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.6...v4.0.7>`__

- Fix a problem parsing generics with string containing semi colon. :vunit_issue:`409`

:vunit_commit:`4.0.6 <v4.0.6>` - 2018-11-15
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.6/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.5...v4.0.6>`__

- Fix a problem where sometimes multiple Ctrl-C where required to abort execution. :vunit_issue:`408`

:vunit_commit:`4.0.5 <v4.0.5>` - 2018-11-07
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.5/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.4...v4.0.5>`__

- Make tb_path absolute again. :vunit_issue:`406`
- Fix ``--export-json`` test location offets for DOS line endings. :vunit_issue:`437`

:vunit_commit:`4.0.4 <v4.0.4>` - 2018-11-05
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.4/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.3...v4.0.4>`__

- Fix broken ActiveHDL support.

:vunit_commit:`4.0.3 <v4.0.3>` - 2018-11-02
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.3/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.2...v4.0.3>`__

- Fix ``set_timeout`` for large values in ModelSim. :vunit_issue:`405`

:vunit_commit:`4.0.2 <v4.0.2>` - 2018-10-25
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.2/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.1...v4.0.2>`__

- Fix missing msg_type in push and pop of msg_t.
- Ensure axi_lite_master always aligns with aclk to avoid VHDL/Verilog simulation mismatch.

:vunit_commit:`4.0.1 <v4.0.1>` - 2018-10-23
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v4.0.0...v4.0.1>`__

- Set value to null when pushing pointer types in queue_t and com to avoid accidental dupliction of ownership.
- Fix broken ram_master.vhd where the response messages where deleted to early.

:vunit_commit:`4.0.0 <v4.0.0>` - 2018-10-22
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/4.0.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.9.0...v4.0.0>`__

- New coverage support:

    The ``--coverage`` flag has been removed in favor of exposing a
    more flexible :ref:`coverage interface <coverage>`. The flag was
    was not flexible enough for many users and we decided to make a
    breaking change to get a better solution moving forward. An
    example of using the new interface can be found here
    :vunit_example:`here <vhdl/coverage>`. For users who liked the old
    flag VUnit supports adding :ref:`custom <custom_cli>` command line
    arguments.

- Add ability to set watchdog timer dynamically. :vunit_issue:`400`

- Skipping protected regions in the Verilog preprocessor.

- Integrate utility to add Vivado IP to a VUnit project see :vunit_example:`example <vhdl/vivado>`.

- Make tb_path work in combination with preprocessing. :vunit_issue:`402`

:vunit_commit:`3.9.0 <v3.9.0>` - 2018-10-11
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.9.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.8.0...v3.9.0>`__

- Verification components
   - Avalon
      - Add Avalon streaming packet signals :vunit_issue:`383`
   - AXI
      - Various AXI BFM improvements.
- Added special JUnit XML format for Bamboo CI server. :vunit_issue:`384`
- Add support for requirements trace-ability via user defined test attributes.
- Add ``--json--export`` flag to export list of all files and tests with associated attributes.
- Add test case filtering for user defined attributes.
   - For example allows marking tests that should be run per commit or only every night.
- Always use the most up to date version of modelsim.ini.

:vunit_commit:`3.8.0 <v3.8.0>` - 2018-08-26
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.8.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.7.0...v3.8.0>`__

- Verification components
   - Avalon
      - Add Avalon memory mapped slave and master. :vunit_issue:`359`
      - Add Avalon stream source and sink. :vunit_issue:`361`
   - AXI
      - Add AXI stream monitor
   - Wishbone
      - Strict command order in wishbone master. :vunit_issue:`372`
- Remove warnings when using built-in RivieraPRO libraries. :vunit_issue:`374`

:vunit_commit:`3.7.0 <v3.7.0>` - 2018-07-21
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.7.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.6.2...v3.7.0>`__

- Fixed lint issues from new pylint version.
- Log output of failed vsim startup to stderr. :vunit_issue:`354`
- Allow case-insensitive lookup of entities. :vunit_issue:`#346`
- Added vhdl_standard attribute at class initialization. :vunit_issue:`#350`
- Adding csv mapping support for files and libraries. :vunit_issue:`349`
- Fix broken vivado example wrt verilog headers. :vunit_issue:`344`
- Allow adding duplicate libraries. :vunit_issue:`341`
- Make adding duplicate file INFO instead of WARNING. :vunit_issue:`341`

:vunit_commit:`3.6.2 <v3.6.2>` - 2018-06-21
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.6.2/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.6.1...v3.6.2>`__

- Fixed memory leak when popping messages from queues.

:vunit_commit:`3.6.1 <v3.6.1>` - 2018-06-20
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.6.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.6.0...v3.6.1>`__

- Increase message id on publish

:vunit_commit:`3.6.0 <v3.6.0>` - 2018-06-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.6.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.5.0...v3.6.0>`__

- Ignore files added twice with identical contents. Closes #341
- Made queues type safe

:vunit_commit:`3.5.0 <v3.5.0>` - 2018-06-04
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.5.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.4.0...v3.5.0>`__

- Added the ability to specify actor for AXI stream masters and slaves
- Added as_sync function to bus masters and AXI stream masters

:vunit_commit:`3.4.0 <v3.4.0>` - 2018-05-31
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.4.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.3.0...v3.4.0>`__

- Updated context files

:vunit_commit:`3.3.0 <v3.3.0>` - 2018-05-24
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.3.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.2.0...v3.3.0>`__

- Add SystemVerilog support for test benches without test cases. :vunit_issue:`328`
- Graceful recovery and error message from failed VHDL parsing.
- Stripping clean from re-compile command.
- Add `JSON-for-VHDL <https://github.com/Paebbels/JSON-for-VHDL>`_ as a submodule.

:vunit_commit:`3.2.0 <v3.2.0>` - 2018-05-07
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.2.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.1.0...v3.2.0>`__

-  Add ``output`` argument to ``post_check``. :vunit_issue:`332`

:vunit_commit:`3.1.0 <v3.1.0>` - 2018-04-27
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.1.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.0.3...v3.1.0>`__

- Add ``--fail-fast`` CLI argument to stop on first test failure.
- Delay simulator selection until VUnit class instantiation instead of import
- Add ``post_run`` to VUnit main.
- Add ``disable_coverage`` compile option.
- Improve AXI read/write slaves

  - Add debug logging
  - Add setting of stall, fifo depth and response latency
  - Add burst length statistics

- Improve AXI-lite master

  - Add debug logging

:vunit_commit:`3.0.3 <v3.0.3>` - 2018-04-22
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.0.3/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.0.2...v3.0.3>`__

- Add ``check_equal`` for real with ``max_diff``
- Improve ``com`` library performance
- Added support for message forwarding
- Improve axi stream verification components
- Add wishbone verification component
- Protect against unexpected mutation of compile and sim options

:vunit_commit:`3.0.2 <v3.0.2>` - 2018-02-22
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.0.2/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.0.1...v3.0.2>`__

- Added is_empty on queues
- Documented queue_t and integer_array_t
- Fixed memory leak


:vunit_commit:`3.0.1 <v3.0.1>` - 2018-02-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.0.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v3.0.0...v3.0.1>`__

- Replace deprecated aliases with constants to work around Sigasi-limitation.

:vunit_commit:`3.0.0 <v3.0.0>` - 2018-02-12
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/3.0.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.4.3...v3.0.0>`__

- *beta* version of a :ref:`verification component <vc_library>` library.

  - AXI read/write slaves
  - Memory model
  - AXI master
  - AXI stream
  - UART RX/TX
  - (B)RAM master

- Hiearchical and color logging support.

- Communication library usability improvements.

  - Push/pop message creation and debugging tools.

:vunit_commit:`2.4.3 <v2.4.3>` - 2018-01-24
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.4.3/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.4.2...v2.4.3>`__

- SystemVerilog: Fix dependency scanning with instance directly after block label  :vunit_issue:`305`.

:vunit_commit:`2.4.2 <v2.4.2>` - 2018-01-20
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.4.2/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.4.1...v2.4.2>`__

- SystemVerilog: Allow MACRO argument within ({[]}). :vunit_issue:`300`.

:vunit_commit:`2.4.1 <v2.4.1>` - 2018-01-16
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.4.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.4.0...v2.4.1>`__

- SystemVerilog: Fix WATCHDOG macro with local timescale set :vunit_issue:`299`.

:vunit_commit:`2.4.0 <v2.4.0>` - 2018-01-12
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.4.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.3.0...v2.4.0>`__

- Ignore test cases in SystemVerilog comments.
- Make integer_array_t metadata get-functions public.
- dictionary: add default value option to get function.
- Improve get_implementation_subset :vunit_issue:`286`.

:vunit_commit:`2.3.0 <v2.3.0>` - 2017-12-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.3.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.2.0...v2.3.0>`__

- Fix commas in Modelsim generics :vunit_issue:`284`.
- Fix problem with vsim_extra_args between entity and architecture in riviera and activehdl.
- Update Verilog preprocessor to read using latin-1 encoding. :vunit_issue:`285`.
- Improve compile printouts :vunit_issue:`283`.
- Add -q/--quiet flag. :vunit_issue:`283`.
- Add printout of output file location. :vunit_issue:`283`.
- Dropped support and testing of Python 3.3 (might still work anyway).
- Fix of Modelsim `--coverage` argument :vunit_issue:`288`.

:vunit_commit:`2.2.0 <v2.2.0>` - 2017-09-29
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.2.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.1.1...v2.2.0>`__

- Add support for tokenizing verilog multi line strings. :vunit_issue:`278`
- Added support for restarting window in check_stable
- Added support for num_cks=0 in check_next.
- Error on adding duplicate source files. :vunit_issue:`274`
- Update Vivado example.
- Add support for non-system-verilog verilog files. :vunit_issue:`268`
- Add dependency scanning of the use of an instantiated package. :vunit_issue:`233`
- Add human readable test output paths. :vunit_issue:`211`

:vunit_commit:`2.1.1 <v2.1.1>` - 2017-07-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.1.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.1.0...v2.1.1>`__

- Fix ``init_file(s)`` broken in 2.1.0
- Fix test bench regex that could match \*_tb\*. :vunit_issue:`263`
- Add external library sanity check. :vunit_issue:`230`
- Add non-empty operation check. :vunit_issue:`250`

:vunit_commit:`2.1.0 <v2.1.0>` - 2017-07-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.1.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.0.1...v2.1.0>`__

- Add ``{rivierapro, modelsim}_init_files.after_load``
  sim_options. They allow setting a list of DO/TCL files to be
  executed during ``vunit_load`` after the top level has been loaded
  using the ``vsim`` command.
- Add input validation to sim and compile options

:vunit_commit:`2.0.1 <v2.0.1>` - 2017-07-10
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.0.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v2.0.0...v2.0.1>`__

- Various small fixes

:vunit_commit:`2.0.0 <v2.0.0>` - 2017-02-21
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/2.0.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.4.0...v2.0.0>`__


Public interface changes
~~~~~~~~~~~~~~~~~~~~~~~~

Some ``run.py`` scripts can be broken by this. Both ``set_generic``
and ``add_config`` works differently internally.

``set_generic`` and ``set_sim_option`` now only affects files added
before the call so reordering within the ``run.py`` can be needed.

``add_config`` on the test case level will no longer discard
configurations added on the test bench level. This affects users
mixing adding configurations on both test and test case level for the
same test bench. Adding a configuration on the test bench level is now
seen as a shorthand for adding the configuration to all test cases
within the test bench. Configurations are only held at the test case
level now. Before there could be configurations on multiple levels
where the most specific level ignored all others. I now recommend
writing a for loop over test_bench.get_tests() adding configurations
to each test individually, see the updated generate_tests example.

We have also forbidden to have configurations without name (""), this
is since the default configuration of all test cases has no name. The
``post_check`` and ``pre_config`` can now be set using
``set_pre_config`` also without using ``add_config`` removing the need
to add a single unnamed configuration and instead setting these in the
default configuration.

This internal restructuring has been made to allow a sane data model
of configurations where they are attached to test cases. This allows
us to expose configurations objects on the public API in the future
allowing users more control and visibility. The current behavior of
configurations is also better documented than it ever was.

I suggest reading the section on :ref:`configurations <configurations>` in the docs.

- Replace ``disable_ieee_warnings`` and ``set_pli`` with corresponding simulation options.
- Adds ``--version`` flag
- Added ``--gui`` flag for GHDL to open gtkwave. Also allows saving waveform without opening gui with ``--gtkwave-fmt`` flag.

:vunit_commit:`1.4.0 <v1.4.0>` - 2017-02-05
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.4.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.3.1...v1.4.0>`__

- Removed bug when compiling Verilog with Active-HDL
- Updated array package
- Added support for simulation init script
- Added support for setting VHDL asserts stop level from run script

:vunit_commit:`1.3.1 <v1.3.1>` - 2017-01-17
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.3.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.3.0...v1.3.1>`__

- Fixed compile errors with GHDL 0.33

:vunit_commit:`1.3.0 <v1.3.0>` - 2017-01-06
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.3.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.2.0...v1.3.0>`__

- Added support for pass acknowledge messages for check subprograms.
- Made design unit duplication a warning instead of runtime error again.

:vunit_commit:`1.2.0 <v1.2.0>` - 2016-12-19
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.2.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.1.1...v1.2.0>`__

- Updated OSVVM submodule

:vunit_commit:`1.1.1 <v1.1.1>` - 2016-12-08
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.1.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v1.0.0...v1.1.1>`__

- Adds vunit_restart and vunit_compile TCL commands for both ModelSim and RivieraPro
- Also support persistent simulator to save startup overhead for RivieraPro.
- Changes --new-vsim into -u/--unique-sim which also works for riviera

:vunit_commit:`1.0.0 <v1.0.0>` - 2016-11-22
-------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/1.0.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.71.0...v1.0.0>`__

- Adds ActiveHDL custom simulation flags support
- Made library simulator flag argument deterministic and same as the order added to VUnit
- Added check_equal between std_logic_vector and natural for unsigned comparison
- Can now set vhdl_standard on an external library
- Added no_parse argument to add_source_files(s) to inhibit any dependency or test scanning
- Renamed public method depends_on to add_dependency_on

:vunit_commit:`0.71.0 <v0.71.0>` - 2016-10-20
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.71.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.70.0...v0.71.0>`__

- Improved location preprocessing control

:vunit_commit:`0.70.0 <v0.70.0>` - 2016-10-13
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.70.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.69.0...v0.70.0>`__

- Hashing test output_path to protect against special characters and long paths on Windows.
- Added ``.vo`` as recognized Verilog file ending.
- Enable setting vhdl_standard per file.

:vunit_commit:`0.69.0 <v0.69.0>` - 2016-09-09
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.69.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.68.1...v0.69.0>`__

Added check_equal for strings.

:vunit_commit:`0.68.1 <v0.68.1>` - 2016-09-03
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.68.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.68.0...v0.68.1>`__

New version to fix broken PyPi upload

:vunit_commit:`0.68.0 <v0.68.0>` - 2016-09-03
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.68.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.67.0...v0.68.0>`__

Added check_equal for time and updated documentation.

:vunit_commit:`0.67.0 <v0.67.0>` - 2016-08-08
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.67.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.66.0...v0.67.0>`__

- A number of minor enhancements and bug fixes
- Added vunit_restart TCL procedure to ModelSim
- Print out remaining number of tests when pressing ctrl-c
- Updated OSVVM and made it a git submodule. Run

.. code-block:: console

   git submodule update --init --recursive

after updating an existing Git repository or

.. code-block:: console

   git clone --recursive https://github.com/VUnit/vunit.git

when creating a new clone to get the OSVVM subdirectory of VUnit populated. Doesn't affect installations made from PyPi

:vunit_commit:`0.66.0 <v0.66.0>` - 2016-04-03
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.66.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.65.0...v0.66.0>`__

- Fixed :vunit_issue:`109`, :vunit_issue:`141`, :vunit_issue:`153`, :vunit_issue:`155`.
- Fixed relative path for multiple drives on windows.

:vunit_commit:`0.65.0 <v0.65.0>` - 2016-03-13
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.65.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.64.0...v0.65.0>`__

- Added sim and compile options to set rivierapro/activehdl flags. :vunit_issue:`143`.
- Removed builtin ``-dbg`` flag to vcom for aldec tools. Use set_compile_option instead to set it yourself.
- Fixed a bug with custom relative output_path.
- Documentation fixes & improvements.
- Update rivierapro and activehdl toolchain discovery. :vunit_issue:`148`.
- Added possibility to set ``VUNIT_<SIMULATOR_NAME>_PATH`` environment
  variable to specify simulation executable path. :vunit_issue:`148`.
- Added ``-k/--keep-compiling`` flag. :vunit_issue:`140`.
- Added optional ``output_path`` argument to ``pre_config``. :vunit_issue:`146`.

:vunit_commit:`0.64.0 <v0.64.0>` - 2016-03-03
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.64.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.63.0...v0.64.0>`__

- Added python version check. Closes :vunit_issue:`141`.
- Not adding .all suffix when there are named configurations

:vunit_commit:`0.63.0 <v0.63.0>` - 2016-03-02
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.63.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.62.1...v0.63.0>`__

- Update test scanner pattern to be based on ``runner_cfg``. :vunit_issue:`138`

:vunit_commit:`0.62.1 <v0.62.1>` - 2016-02-28
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.62.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.62.0...v0.62.1>`__


:vunit_commit:`0.62.0 <v0.62.0>` - 2016-02-27
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.62.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.61.0...v0.62.0>`__

- Early runtime error when gtkwave is missing. Closes :vunit_issue:`137`
- Added add_compile_option. Closes :vunit_issue:`118`

:vunit_commit:`0.61.0 <v0.61.0>` - 2016-02-23
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.61.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.60.1...v0.61.0>`__

- Adds ``.all`` suffix to test benches with no test to better align with XUnit architecture.
  - Enables better hierarchical JUnit XML report view in Jenkins.
- Fixes :vunit_issue:`129`.

:vunit_commit:`0.60.1 <v0.60.1>` - 2016-02-16
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.60.1/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.60.0...v0.60.1>`__

- Avoids crash with errors in Verilog defines from Python string in run.py

:vunit_commit:`0.60.0 <v0.60.0>` - 2016-02-15
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.60.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.59.0...v0.60.0>`__

- Better error messages when there are circular dependencies.
- Added ``defines`` argument to add_source_file(s) :vunit_issue:`126`
- Made ``--files`` deterministic with Python 3 :vunit_issue:`116`

:vunit_commit:`0.59.0 <v0.59.0>` - 2016-02-13
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.59.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.58.0...v0.59.0>`__

- Covered a miss in circular dependency detection.
- Added detection of circular includes and macro expansions in verilog preprocessing.
- Added caching of verilog parse results for significant speed when running run.py more than once.

:vunit_commit:`0.58.0 <v0.58.0>` - 2016-02-11
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.58.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.57.0...v0.58.0>`__

- Parsing Verilog package references. :vunit_issue:`119`
- Added ``scan_tests_from_file`` public method. :vunit_issue:`121`.

:vunit_commit:`0.57.0 <v0.57.0>` - 2016-02-08
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.57.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.56.0...v0.57.0>`__

- Adds ``include_dirs`` argument also to ``Library`` add_source_file(s)
- Ignores more builtin Verilog preprocessor directives.

:vunit_commit:`0.56.0 <v0.56.0>` - 2016-02-07
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.56.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.54.0...v0.56.0>`__

- Verilog preprocessing of resetall / undefineall / undef

:vunit_commit:`0.54.0 <v0.54.0>` - 2016-02-06
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.54.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.53.0...v0.54.0>`__

- Adds support for Verilog preprocessor ifdef/ifndef/elsif/else/endif
- Fixes regression in modelsim persistent mode. Makes many short tests faster.

:vunit_commit:`0.53.0 <v0.53.0>` - 2016-02-06
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.53.0/>`__ | `Commits since previous release <https://github.com/VUnit/vunit/compare/v0.52.0...v0.53.0>`__

- ``add_source_files`` accepts a list of files
- Added ``-f/--files`` command line flag to list all files in compile order
- Verilog parser improvements in robustness and error messages.

:vunit_commit:`0.52.0 <v0.52.0>` - 2016-01-29
---------------------------------------------


`Download from PyPI <https://pypi.python.org/pypi/vunit_hdl/0.52.0/>`__

Added function to get the number of messages missed by a com package actor.
