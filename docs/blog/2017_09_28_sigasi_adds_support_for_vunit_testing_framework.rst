:tags: VUnit
:author: lasplund
:excerpt: 1

Sigasi Adds Support for VUnit Testing Framework
===============================================

.. NOTE:: This article was originally posted on `LinkedIn <https://www.linkedin.com/pulse/sigasi-adds-support-vunit-lars-asplund>`__
   where you may find some comments on its contents.

.. figure:: img/vunit_sigasistudio.jpg
   :alt: Sigasi Support
   :align: center

`VUnit <http://vunit.github.io/index.html>`__ was born out of
frustration over the lack of an efficient test framework. The
continuous and automated approach to testing I used for software
development was not available for VHDL. I didn't get the quick
feedback on newly introduced bugs and design flaws so I wasn't as
productive as I knew I could be.

The Eclipse-based `Sigasi Studio <http://www.sigasi.com>`__ was also
born out of frustration. Frustration over not having a modern IDE
providing features such as instant feedback on syntactic errors in
your code.

    *"We felt a need for new and better tools for professional VHDL design, akin to well-known IDEs like Eclipse and Visual Studio."*

    -- Philippe Faes and Hendrik Eeckhaut, founders of Sigasi

With a shared focus on short feedback loops it became natural for me
to use both these tools. Sigasi Studio for design entry and VUnit for
testing.

However, rather than using these tools in separation we can do better
by having the IDE support test creation, control test execution and
collect the results. All error feedback in one place. This is actually
very common when using Eclipse with software languages and with the
new Sigasi Studio 3.6 release the company is taking the `first steps
<http://insights.sigasi.com/tech/vunit-quickfix.html>`__ towards such
an integration by recognizing VUnit testbenches and
supporting their creation. I'm very much looking forward to the coming
releases of Sigasi Studio!

