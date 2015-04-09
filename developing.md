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

```shell
# Run all tests
vunit/ > python -m unittest discover vunit/test

# Run just the unit tests
vunit/ > python -m unittest discover vunit/test/unit
```

The test suites must work using both Python 2.7 and Python 3.x.

## Dependencies
Other that the dependencies required to use VUnit as a user the following are also required for developers to run the test suite:
* [mock](https://pypi.python.org/pypi/mock) 
  * For Python 2.7 only, built into Python 3.x
* [pep8](https://pypi.python.org/pypi/pep8)
* [pylint](https://pypi.python.org/pypi/pylint)
