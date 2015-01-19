# What is VUnit?

VUnit is an open source unit testing framework for VHDL released under the terms of Mozilla Public License, v. 2.0. It features the functionality needed to realize continuous and automated testing of your VHDL code. VUnit doesn't replace but rather complements traditional testing methodologies by supporting a "test early and often" approach through automation.

# Project Mission

The VUnit project mission is to apply best SW testing practises to the world of VHDL by providing the tools missing to adapt to such practises. The major missing piece is the unit testing framework, hence the name V(HDL)Unit. However, VUnit also provides supporting functionality not normally considered as a part of an unit testing framework. 

# Main Features
* Builds on the commonly used [xUnit](http://en.wikipedia.org/wiki/XUnit) architecture.
* Python test runner that enables powerful test administration, can handle VHDL fatal run-time errors (e.g. division by zero), and ensures test case independence.
* Scanners for identifying files, tests, file dependencies, and file changes enable for automatic (re)compilation and execution of test suites.
* Scripting as well as command line support.
* Support for running same test suite with different generics.
* VHDL test runner which enables test execution for not fully supported simulators.
* Assertion checker library that extends VHDL built-in support (assert).
* Logging framework supporting display and file output, different log levels, filtering on level and design hierarchy, output formatting and multiple loggers. Spreadsheet tool integration.
* Location preprocessor that traces log and check calls back to file and line number.
* JUnit report files for better [Jenkins](http://jenkins-ci.org/) integration.

# Requirements
VUnit depends on a number of components as listed below. Full VUnit functionality requires Python and a simulator supported by the VUnit Python test runner. However, VUnit can run with limited functionality entirely within VHDL which means that unsupported simulators can be used as well. Prototype work has been done to fully support other simulators but this work is yet to be completed and released.
## VHDL
* VHDL-93
* VHDL-2002
* VHDL-2008

## Operating systems
* Windows
* Linux

## Python
* Python 2.7
* Python 3.3 or higher

## Simulators
* Mentor Graphics ModelSim (tested with 10.1 - 10.3)

# Getting Started
There are a number of ways to get started.

*  Have a look at the examples under [examples](examples). The examples in [logging](examples/logging) and [check](examples/check) are tutorials that should be single-stepped in your simulator.
*  The [user guide](user_guide.md) will give an introduction on how VUnit is used with Python scripting and from the command line
*  There are also various presentations of VUnit on [YouTube](https://www.youtube.com/channel/UCCPVCaeWkz6C95aRUTbIwdg)

# Main Contributors
Lars Asplund  
Olof Kraigher

# License 

VUnit is released under the terms of [Mozilla Public
License, v. 2.0](http://mozilla.org/MPL/2.0/).

&copy; 2014-2015 Lars Asplund, lars.anders.asplund@gmail.com.


