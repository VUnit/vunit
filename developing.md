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
