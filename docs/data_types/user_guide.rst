.. _data_types_library:

Data Types
==========

Introduction
------------
VUnit comes with a number of convenient data types included:

:queue_t: A queue (fifo) which to which any VHDL primitive data type
          can be pushed and popped by serializing the data to bytes
          internally. This queue can be used to for example push
          expected data from a driver process to a checker process in
          a test bench. :ref:`Queue API <queue_pkg>`

:integer_array_t: An dynamic array of integers in up to 3 dimensions.
                  Supports dynamic append and reshape operations.
                  Supports reading and writing data to/from *.csv* or *.raw* byte files.
                  :ref:`Integer array API <integer_array_pkg>`

.. _queue_pkg:

queue package
-------------
.. literalinclude:: ../../vunit/vhdl/data_types/src/queue_pkg.vhd
   :language: vhdl
   :lines: 7-

.. _integer_array_pkg:

integer_array  package
----------------------
.. literalinclude:: ../../vunit/vhdl/data_types/src/integer_array_pkg.vhd
   :language: vhdl
   :lines: 7-
