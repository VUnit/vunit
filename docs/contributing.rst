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
   # Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com


Python related
--------------

Running the tests
~~~~~~~~~~~~~~~~~

The test suite is divided into three parts:

**vunit/test/unit/**
   Short and concise unit tests for internal modules and classes.

**vunit/test/acceptance/**
   End to end tests of public functionality. Depends on external tools
   such as simulators.

**vunit/test/lint/**
   Style checks such as pycodestyle and license header verification.

The test suites must pass with both Python 2.7 and Python 3.x as well
as with all supported simulators.

For running the test locally we recommend using `pytest <https://pypi.python.org/pypi/pytest>`__.

Example
'''''''
.. code-block:: shell
   :caption: Example of running all unit tests

   pytest vunit/test/unit/

Dependencies
~~~~~~~~~~~~

Other than the dependencies required to use VUnit as a user the
following are also required for developers to run the test suite manually:

`mock <https://pypi.python.org/pypi/mock>`__
   For Python 2.7 only, built into Python 3.x

`pycodestyle <https://pypi.python.org/pypi/pycodestyle>`__
   Coding style check.

`pylint <https://pypi.python.org/pypi/pylint>`__
   Code analysis.

Code coverage
~~~~~~~~~~~~~

Code coverage can be measured using the
`coverage <https://pypi.python.org/pypi/coverage>`__ tool. The following
commands measure the code coverage while running the entire test suite:

.. code:: console

    vunit/ > coverage run --branch --source vunit/ -m unittest discover vunit/test/
    vunit/ > coverage html --directory=htmlcov
    vunit/ > open htmlcov/index.html

Developers should ensure that new code is well covered. As of writing
this paragraph the total coverage was 92%. Missing coverage can be
analyzed by opening the generated *htmlcov/index.html* produced by the
above commands.

VHDL related
------------

Running the tests
~~~~~~~~~~~~~~~~~
Each part of the VUnit VHDL code base has tests with a corresponding ``run.py`` file.
For example :vunit_file:`vunit/vhdl/verification_components/run.py`.

Example
'''''''
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
VUnit runs all test and lint checks on both Windows using AppVeyor and
Linux using Travis CI with several versions of Python. GHDL is used to
run the VHDL tests of all our libraries and examples.

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
"environments" should be tested. For example, assume a developer uses Python 2.7
and Modelsim and would like to test changes using tools available in his
environment:

.. code-block:: console

    vunit/ > tox -e py27-unit,py27-acceptance-modelsim

A full list of test environments can be seen by issuing the following command:

.. code-block:: console

    vunit/ > tox -l


Making releases
~~~~~~~~~~~~~~~

Releases are automatically made by Travic CI on any ``master`` commit
which is tagged.

To create a new tagged release commit:

- Create corresponding release notes in ``docs/release_notes/X.Y.Z.rst``.
   - The release notes files in ``docs/release_notes/`` are used to
     automatically generate the :ref:`release notes <release_notes>`.
- Execute ``python tools/release.py create X.Y.Z``.
   - Will make commit with the new ``about.py`` version and release notes and tag it.
   - Will make another commit setting ``about.py`` to the next pre release candidate version.
- Push the tag to remote to trigger the release build.
   -  ``git push origin vX.Y.Z``
- If the release build is successful, you can push the two commits to master.
   -  ``git push origin master``
   - If, in the meantime, a new commit has come into origin/master the two
     commits have to be merged into origin/master.


Travic CI makes a release by uploading a new package to PyPI when a tag
named ``vX.Y.Z`` is found in Git. A new release will not be made if:

- The ``X.Y.Z`` release is already on PyPI.
- The repo tag does not exist.
