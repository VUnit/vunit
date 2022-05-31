.. _continuous_integration:

Introduction
############

Because VUnit features the functionality needed to realize continuous and automated testing of HDL code, it is a very valuable
resource in Continuous Integration (CI) environments. Once a project ``run.py`` has been setup, tests can be run in a headless
environment. Optionally, a standardized `Xunit <https://en.wikipedia.org/wiki/List_of_unit_testing_frameworks>`_ style output
can be saved to a file; which allows dynamic interpretation of results and avoids custom (and error-prone) parsing of the logs.
After tests have finished running, the ``test_output.xml`` file can be parsed using standard xUnit test parsers such as
`Jenkins xUnit Plugin <http://wiki.jenkins-ci.org/display/JENKINS/xUnit+Plugin>`_.

.. code-block:: console
   :caption: Execute VUnit tests on CI server with XML output

    python run.py --xunit-xml test_output.xml

Furthermore, VUnit can be easily executed on many different platforms (either operating systems or architectures), because it
is written in Python, which is an interpreted language. However, besides own HDL sources and VUnit, a
`HDL compiler/simulator <https://en.wikipedia.org/wiki/List_of_HDL_simulators>`_ is required in order to run the tests. Since
most HDL simulators are written using compiled languages, releases are typically platform specific. Hence, installation
and setup might be non trivial. This is specially so with non-free tools that require license servers to be configured. This
might represent a burden for the adoption of continuous integration in hardware development teams, as it falls into the
category of dev ops.

Nevertheless, thanks to free and public CI/CD services, along with the striking research about portable development
environment solutions, there are a bunch of alternatives to ease the path. In this section, solutions are grouped into three
categories: :ref:`continuous_integration:script`, :ref:`continuous_integration:container` and :ref:`continuous_integration:manual`.
