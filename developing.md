# Developing VUnit
Code contributions are expected to pass all tests and style checks. 

## Running the tests
The test suite is divided into three parts:

1. **vunit/test/unit/**
   - Short and concise unit tests for internal modules and classes.
2. **vunit/test/acceptance/**
   - End to end tests of public functionality. Depends on external tools such as simulators.
3. **vunit/test/lint/**
   - Style checks such as PEP8 and license header verification.

```console
# Run all tests
vunit/ > python -m unittest discover vunit/test

# Run just the unit tests
vunit/ > python -m unittest discover vunit/test/unit
```

The test suites must work using both Python 2.7 and Python 3.x.

### Running with different simulator back-ends
VUnit supports both ModelSim and GHDL and the acceptance tests must work for both simulators. The acceptance tests can be run for a specific simulator by setting the `VUNIT_SIMULATOR` environment variable:
```console
vunit/ > VUNIT_SIMULATOR=ghdl python -m unittest discover vunit/test/acceptance/
```

## Dependencies
Other that the dependencies required to use VUnit as a user the following are also required for developers to run the test suite:
* [mock](https://pypi.python.org/pypi/mock) 
  * For Python 2.7 only, built into Python 3.x
* [pep8](https://pypi.python.org/pypi/pep8)
* [pylint](https://pypi.python.org/pypi/pylint)

## Code coverage
Code coverage can be measured using the [coverage](https://pypi.python.org/pypi/coverage) tool.
The following commands measure the code coverage while running the entire test suite:
```console
vunit/ > coverage run --branch --source vunit/ -m unittest discover vunit/test/
vunit/ > coverage html --directory=htmlcov
vunit/ > open htmlcov/index.html
```
Developers should ensure that new code is well covered. As of writing this paragraph the total coverage was 92%.
Missing coverage can be analyzed by opening the generated *htmlcov/index.html* produced by the above commands.
