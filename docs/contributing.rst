Contributing
============
Contributing in the form of code, feedback, ideas or bug reports are
welcome. Code contributions are expected to pass all tests and style
checks. If there are any problems let us know.

Before doing any major changes we recommend creating an issue or
chatting with us on gitter to discuss first. In this way you do not
get started on the wrong track and wasting time.

Being a testing framework we value automated testing and all
contributions in both the Python and VHDL/SystemVerilog domain are
expected to add new tests along with the new functionality.

Copyright
---------
Any contribution must give the copyright to Lars Asplund.
This is necessary to manage the project freely.
Copyright is given by adding the copyright notice to the beginning of each file.

.. code-block:: python

   # This Source Code Form is subject to the terms of the Mozilla Public
   # License, v. 2.0. If a copy of the MPL was not distributed with this file,
   # You can obtain one at http://mozilla.org/MPL/2.0/.
   #
   # Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com


Python related
--------------

Running the Python tests
~~~~~~~~~~~~~~~~~~~~~~~~

The test suite is divided into three parts:

**tests/unit/**
   Short and concise unit tests for internal modules and classes.

**tests/acceptance/**
   End to end tests of public functionality. Depends on external tools
   such as simulators.

**tests/lint/**
   Style checks such as pycodestyle and license header verification.

The test suites must pass with Python 3.x as well as with all supported simulators.

For running the tests locally we recommend using `pytest <https://pypi.python.org/pypi/pytest>`__.
In fact, ``pytest`` is required for running the acceptance tests, because some specific features are used for allowing
certain tests to fail.
See :doc:`pytest:how-to/skipping`.

.. code-block:: shell
   :caption: Example of running all unit tests

   pytest tests/unit/

Dependencies
~~~~~~~~~~~~

Other than the dependencies required to use VUnit as a user the
following are also required for developers to run the test suite manually:

`pycodestyle <https://pypi.python.org/pypi/pycodestyle>`__
   Coding style check.

`pylint <https://pypi.python.org/pypi/pylint>`__
   Code analysis.

`mypy <http://www.mypy-lang.org/>`__
   Optional static typing for Python.

Code coverage
~~~~~~~~~~~~~

Code coverage can be measured using the
`coverage <https://pypi.python.org/pypi/coverage>`__ tool. The following
commands measure the code coverage while running the entire test suite:

.. code:: console

    vunit/ > coverage run --branch --source vunit/ -m unittest discover tests/
    vunit/ > coverage html --directory=htmlcov
    vunit/ > open htmlcov/index.html

Developers should ensure that new code is well covered. As of writing
this paragraph the total coverage was 92%. Missing coverage can be
analyzed by opening the generated *htmlcov/index.html* produced by the
above commands.

VHDL related
------------

Running the VHDL tests
~~~~~~~~~~~~~~~~~~~~~~
Each part of the VUnit VHDL code base has tests with a corresponding ``run.py`` file.
For example :vunit_file:`vunit/vhdl/verification_components/run.py`.

VHDL example
''''''''''''
.. code-block:: shell
   :caption: Example of running all verification component tests

   python vunit/vhdl/verification_components/run.py


Coding Style
~~~~~~~~~~~~
Contributions of VHDL code should blend in with the VUnit code style.

- Use lower case and ``snake_case`` for all identifiers and keywords.
- Do not use prefixes or suffixes like ``_c`` or ``_g`` for constants.
- Use ``_t`` suffix for type like ``<typename>_t``.
- Never use the fact that VHDL is case-insensitive; Do not use ``Foo``
  and ``foo`` to refer to the same identifier.
- Name array types ``<base_type_name>_vec_t``
- Name packages with suffix ``_pkg``
- Name files the same as the package or entity they contain such as ``<entity_name>.vhd``
- Never put more than one entity/package in the same file.
- Keep the architecture in the same file as the entity unless there
  are several architectures. When there are several architectures put
  them all in separate files named
  ``<entity_name>_<architecture_name>.vhd``.
- Put comments documenting functions and procedures above the
  declaration in the package header rather than the definition in the
  package body.

Regarding formatting use look at other VHDL files and follow that
style. For example :vunit_file:`examples/vhdl/uart/src/uart_tx.vhd`


Continous Integration
---------------------
VUnit runs all test and lint checks on both GNU/Linux and Windows
with several versions of Python (typically, the oldest and newest
supported by both VUnit and the CI environment). `GHDL <https://github.com/ghdl/ghdl>`_
is used to run the VHDL tests of all our libraries and examples.

All tests will be automatically run on any pull request and they are
expected to pass for us to approve the merge.

Any commit on master that has a successful CI run will automatically
update the `VUnit website <https://vunit.github.io>`__

Testing with Tox
~~~~~~~~~~~~~~~~
VUnit uses the Python `tox <http://tox.readthedocs.org/>`__ tool in
the CI flow. Typically developers do not need to run this on their
local machine.

Tox makes it easier to automatically test VUnit in various
configurations. Tox automates creation of virtual environments and
installation of dependencies needed for testing. In fact, all of the
tests can be run in a single command:

.. code-block:: console

    vunit/ > tox

If tox is not available in your Python environment, it can be installed from
PyPI with pip:

.. code-block:: console

    vunit/ > pip install tox

For most developers, running the full testsuite will likely lead to failed test
cases because not all Python interpreters or HDL simulators are installed in
their environment. More focused testing is possible by specifying which tox
"environments" should be tested. For example, assume a developer uses Python 3.8
and Modelsim and would like to test changes using tools available in his
environment:

.. code-block:: console

    vunit/ > tox -e py38-unit,py38-acceptance-modelsim

A full list of test environments can be seen by issuing the following command:

.. code-block:: console

    vunit/ > tox -l


Making releases
~~~~~~~~~~~~~~~

.. IMPORTANT::
  Reference :ref:`release_notes_instructions` for creating relevant news fragments that will be added to the :ref:`release_notes`.

Releases are automatically made by GitHub Actions on any ``master`` commit which is tagged.

To create a new tagged release commit:

- Build the docs and review the content of ``docs/news.inc``.

  - If necessary, create additional news files and build the docs again.

- Add the news summary as the release notes and remove news fragments:

  .. code-block:: python

     mv docs/news.inc docs/release_notes/X.Y.Z.rst
     git add docs/release_notes/X.Y.Z.rst
     git rm -f docs/news.d/*.rst

- Execute ``python tools/release.py create X.Y.Z``.
   - Will make and tag a commit with the new ``about.py`` version, the release notes and removed news files.
   - Will make another commit setting ``about.py`` to the next development version.

- Push the tag to remote to trigger the release build.
   - ``git push origin vX.Y.Z``

- If the release build is successful, you can push the two commits to master.
   - ``git push origin master``
   - If, in the meantime, a new commit has come into origin/master the two commits have to be merged into origin/master.

The CI service makes a release by uploading a new package to PyPI when a tag named ``vX.Y.Z`` is found in Git.
A new release will not be made if:

- The ``X.Y.Z`` release is already on PyPI.
- The repo tag does not exist.

Submodule related
-----------------

As of VUnit v4.7.0, the version of the submodules is printed in the corresponding ``add_*`` methods of
:vunit_file:`builtins.py <vunit/builtins.py>`.
Therefore, when bumping the submodules, maintainers/contributors need to remember modifying the string to match the new
version.

Furthermore, since OSVVM is tagged periodically, bumping from tag to tag is strongly suggested.

.. _release_notes_instructions:

Release Notes Instructions
--------------------------

The :vunit_file:`release notes directory <docs/news.d>` contains "newsfragments" which
are short (`reST formatted
<https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html>`_) files that
contain information for users.

Make sure to use full sentences in the **past or present tense** and use punctuation.

Each file should be named like ``<issue #>.<type>.rst``, where ``<issue #>`` is the
GitHub issue or pull request number, and ``<type>`` is one of:

* ``breaking``:may break existing functionality; such as feature removal or behavior change.
* ``bugfix``: fixes a bug.
* ``doc``: related to the documentation.
* ``deprecation``: feature deprecation.
* ``feature``: backwards compatible feature addition or improvement.
* ``misc``: a ticket was closed, but it is not necessarily important for the user.

For example: ``123.feature.rst``, ``456.bugfix.rst``.

.. HINT::
  ``towncrier`` preserves multiple paragraphs and formatting
  (code blocks, lists, and so on), but for entries other than features, it is usually better to stick
  to a single paragraph to keep it concise.
