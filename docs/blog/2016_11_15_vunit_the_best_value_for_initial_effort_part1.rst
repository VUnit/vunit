:tags: VUnit
:author: lasplund
:excerpt: 1

VUnit - The Best Value for Initial Effort - Part 1
==================================================

.. NOTE:: This article was originally posted on `LinkedIn <https://www.linkedin.com/pulse/vunit-best-value-initial-effort-lars-asplund>`__
   where you may find some comments on its contents.

.. figure:: img/bestvalue1.jpg
   :alt: Best Value Part 1
   :align: center

In the book Effective Coding with VHDL published this summer VUnit was
presented as the most advanced testing framework of its kind.

    *For VHDL, the most advanced framework is VUnit*

VUnit is the framework providing the most extensive set of features
for full test automation and if you think of advanced as something
being feature-rich this statement makes perfect sense. However, the
word advanced can also be intimidating, indicating something that is
hard to learn and use. We've always been very aware of this potential
problem and worked hard to prevent the advanced features from messing
up the simple stuff. The VUnit you see today is actually the third
generation. The first two never made it to the public because we
didn't think the basic principles were simple enough. Don't get me
wrong, we want to be feature complete but equally important is the
ease of getting started. This must also be true

    *For VHDL, VUnit gives the best value for initial effort*

I think VUnit has achieved this and I will show why in a number of
short blogs and video clips. The first clip is about installing
VUnit. This is something that can be done in `less than a minute
<http://www.youtube.com/watch?v=Kd1KYvn8Wog>`__.

When companies and individuals start using VUnit they take the path of
least resistance. What that path is depends on the starting point but
one common approach is the following.

- Individuals start using VUnit on their own code and then it spreads
  among their colleagues. It's much easier to get started and lead by
  example than trying to get an up-front corporate decision.
- VUnit is initially used to fully automate testing for already existing
  and self-checking testbenches. There is no added value in replacing
  existing VHDL assert statements with the checks provided by VUnit even
  though they provide many more capabilities. These checks are
  introduced when developing new testbenches or when the old ones are
  refactored for some other reason.
- VUnit is adopted in small bits and pieces. Why? Because you can and it's much more convenient.

Based on this approach the upcoming blogs will present VUnit adoption in the following order

- The second blog will show how you can create a single run script that
  provides automated and incremental compilation of all your project
  testbenches. This script is simulator vendor agnostic and is another
  one minute effort in my example project downloaded from `opencores
  <http://opencores.org>`__. The
  project consists of 18 VHDL files verified by 11 testbenches.
- The third blog will show how 5 lines of code added to your testbenches
  will give you a fully automated test environment with a single call to
  the previously developed run script. Most projects will also
  experience a significant increase in simulation speed due to the
  multicore simulation support provided by VUnit (~4x on a quad core
  computer).

The steps above were less than 10 minutes of work for my example
project. Much value for almost no initial effort and hardly without
touching existing VHDL code.

I will then wrap up this getting started with VUnit blog series with

- Developing and debugging with VUnit - Switching between working in the
  simulator GUI and using the run script.
- Using test cases - Speed up the simulation even more.
- Using VUnit configurations - Running your testbenches with different generics.

Comments and questions are encouraged. You can do it here on LinkedIn
but I highly recommend using our user community `chat room
<http://gitter.im/VUnit/vunit>`__. It's a
better technical platform for Q&A but more important is that you will
hear the voices of other users, not just the potentially single-sided
opinions of the VUnit developers. We have different backgrounds,
different skills, and different opinions so it becomes a much more
interesting discussion.
