:tags: VUnit
:author: lasplund
:excerpt: 1

VUnit Events
============

What You Will Learn
-------------------

1. An improved method for synchronizing various components of your testbench.
2. Techniques to ensure your testbench does not terminate prematurely, before the DUT has been fully verified.
3. Ways to quickly identify where the testbench is stuck on timeout or other errors.
4. A method for generating a system "core dump" for easier debugging when errors are detected.

Introduction
------------

.. include:: ../data_types/event_user_guide.rst
   :start-after: ------------
   :end-before: Fortunately VUnit provides such a solution

Fortunately VUnit provides such a solution. It's called VUnit phases and it will be the topic for the next blog.

