.. _data_types_library:

Data Types User Guide
#####################

VUnit comes with a number of convenient data types included:

* **event_t and basic_event_t** (:ref:`event user guide <event_user_guide>`)

* **queue_t** (:ref:`Queue API <queue_pkg>`)
    Queue (FIFO) to which any VHDL primitive data type can be pushed and
    popped (by serializing data to bytes internally). This queue can be
    used to, for example, push expected data from a driver process to a
    checker process in a test bench.

* **integer_array_t** (:ref:`Integer array API <integer_array_pkg>`)
    Dynamic array of integers in up to 3 dimensions. Supports dynamic
    append and reshape operations, and reading/writing data to/from
    *.csv* or *.raw* byte files.

.. toctree::
   :hidden:

   event_user_guide
   queue
   integer_array

.. _data_types_library:external:

External VHDL API
=================

.. include:: external_api.rst
