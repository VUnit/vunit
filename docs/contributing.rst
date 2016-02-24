Contributing
============
Contributing in the form of code, feedback, ideas or bug reports are
welcome. Code contributions are expected to pass all tests and style
checks. If there are any problems let us know.

Running the tests
-----------------

The test suite is divided into three parts:

**vunit/test/unit/**
   Short and concise unit tests for internal modules and classes.

**vunit/test/acceptance/**
   End to end tests of public functionality. Depends on external tools
   such as simulators.

**vunit/test/lint/**
   Style checks such as PEP8 and license header verification.

The test suites must with both Python 2.7 and Python 3.x as well
as with all supported simulators.

Testing with Tox
~~~~~~~~~~~~~~~~
VUnit uses the Python `tox <http://tox.readthedocs.org/>`__ tool. Tox
makes it easier to automatically test VUnit in various
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

Dependencies
------------

Other than the dependencies required to use VUnit as a user the
following are also required for developers to run the test suite manually:

`mock <https://pypi.python.org/pypi/mock>`__
   For Python 2.7 only, built into Python 3.x

`pep8 <https://pypi.python.org/pypi/pep8>`__
   Coding style check.

`pylint <https://pypi.python.org/pypi/pylint>`__
   Code analysis.

Code coverage
-------------

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
