:tags: VUnit
:author: lasplund
:excerpt: 1

VUnit - The Best Value for Initial Effort - Part 2
==================================================

.. NOTE:: This article was originally posted on `LinkedIn <https://www.linkedin.com/pulse/vunit-best-value-initial-effort-part-2-lars-asplund>`__
   where you may find some comments on its contents.

.. figure:: img/bestvalue2.jpg
   :alt: Best Value Part 2
   :align: center

In the previous `blog
<http://www.linkedin.com/pulse/vunit-best-value-initial-effort-lars-asplund>`__
I showed how `VUnit <http://vunit.github.io/index.html>`__ can be installed in less than
one minute. This was the first step towards my goal of showing that

    *For VHDL, VUnit gives the best value for initial effort*

The first step was certainly almost effortless but to be honest it
didn't provide any value whatsoever. Time to change that by spending
another minute.

In my second `video clip
<http://www.youtube.com/watch?v=60oWpYOpLlQ>`__ I will show how you
can create a compile
script for your project within a minute. This script provides
incremental compilation, meaning that it will find your source files,
figure out their dependencies to create a compile order, and then
compile what's needed based on what has changed since last
compilation. Once you created such a script you rarely change it,
files can normally be added and removed without modifications.

Another minute of work but this time some real added value. The only
requirement is that you are using one of the supported `simulators
<http://vunit.github.io/about.html#simulators>`__,
currently ModelSim/Questa, Riviera-Pro, Active-HDL, GHDL, and Cadence
Incisive. Support for other simulators is `planned
<http://github.com/VUnit/vunit/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3A%22simulator%20support%22>`__.

In my next blog I will use the same script to also run all the
testbenches in my project and present a test report. Until then you
can have a more detailed look at the script created by downloading the
`example project <http://github.com/LarsAsplund/udp_ip_stack>`__.

Comments and questions are encouraged. You can do it here on LinkedIn
but even better is to use our user community `chat room
<http://gitter.im/VUnit/vunit>`__.
