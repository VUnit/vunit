.. _memory_model:

Memory Model
============
To verify devices such as AXI-masters that access an external memory
space it is useful to have a memory model with the following capabilities:

1. Allocate data buffers
2. Write data to input buffers
3. Set expected data for output buffers
4. Read data from output buffers
5. Set read/write permission on memory regions

In the test bench the Device Under Test (DUT) is connected to a
verification component (VC) such as an AXI slave bus functional
model. The VC has a reference to the memory model and will translate
all bus transactions into byte accesses to the memory model.

When the VC makes byte accesses to the memory models they are checked
for permission and expected data buffer violations. In case of
violations error messages give valuable contextual information such as
the name of the buffer where an offending access has been made as well
as the relative address within the buffer.

The test bench can provide input data to the DUT by allocating a data
buffer and filling it with data. Strict access permissions can be set
to ensure that the DUT does not make unwanted memory accesses. Output
data can be checked by reading from the output data buffer and
comparing to expected values. Expected data can also be set directly
on the memory model with the advantage that the error is detected as
soon as the first incorrect byte is written to the memory which can
provide valuable contextual information.

Memory Model Utilities
----------------------
There is also a ``memory_utils_pkg`` providing functions to read and
write other VUnit data types such as ``integer_array_t`` to the memory
model.

API
---

.. literalinclude:: ../../vunit/vhdl/verification_components/src/memory_pkg.vhd
   :caption: Memory model API
   :language: vhdl
   :lines: 7-
