:tags: VUnit
:author: lasplund
:excerpt: 1

VUnit - The Best Value for Initial Effort - Part 3
==================================================

.. NOTE:: This article was originally posted on `LinkedIn <https://www.linkedin.com/pulse/vunit-best-value-initial-effort-part-3-lars-asplund/>`__
   where you may find some comments on its contents.

.. figure:: img/bestvalue3.jpg
   :alt: Best Value Part 3
   :align: center

After spending one minute on `installing VUnit
<http://www.linkedin.com/pulse/vunit-best-value-initial-effort-lars-asplund>`__
and one minute on `creating a run script
<http://www.linkedin.com/pulse/vunit-best-value-initial-effort-part-2-lars-asplund>`__
for incremental compilation it is time to go full automation. Five
lines of code or roughly 30 seconds of work for each testbench is what
it takes to get the following added values:

- A single command to verify your project designs or, which I will
  show in the next blog, part of the designs.
- Support for distributing the simulations over many CPU cores. If you
  have a quad core CPU you can have a 4x speed-up. This requires more
  simulator licenses but if you use a free version of a commercial
  simulator or the open source GHDL that is no problem.
- Continuous integration with the help of tools like `Jenkins
  <http://wiki.jenkins-ci.org/display/JENKINS/Meet+Jenkins>`__ and
  `Travis <http://travis-ci.org/>`__. Did you notice the build status
  badge in the `example project repository
  <http://github.com/LarsAsplund/udp_ip_stack>`__? Whenever someone
  pushes new code to the repository Travis will use VUnit to run all
  the tests for that code and present the result. Click on the badge
  or `here <http://travis-ci.org/LarsAsplund/udp_ip_stack>`__ and you'll see.

This `video <http://youtu.be/_qytd_9Yroc>`__ clip will show the
details for this step and the resulting code is in my `repository
<http://github.com/LarsAsplund/udp_ip_stack>`__.

All in all I've spent less than ten minutes to convert this project
but I haven't really made any changes to how the testbenches are
designed. If you look at the code you will find several thousands of
assert statements which can be enhanced with VUnit
functionality. However, replacing all of them is not a quick fix so
VUnit must be able to handle legacy asserts in order to be the
low-effort solution we're striving for. A better approach is to
continuously improve on the code you have, for example when developing
tests for new functionality, making manual testbenches self-checking,
or when debugging designs.

This was all for now. In the next blog I will talk about test cases in
VUnit and how they bring clarity and extra speed to your
testbenches. As always, comments and questions are welcomed here or in
our user community `chat room <http://gitter.im/VUnit/vunit>`__.



