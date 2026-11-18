---
name: exchange-queued-data
description: Exchange transactions and expected results between concurrent VHDL testbench processes using VUnit queues. Use when verifying independent interfaces, buffered data paths, or testbenches where processes produce and consume data at different rates.
license: MPL-2.0
---

# Exchange Queued Data with VUnit

1. **Decouple concurrent processes.** Use VUnit queues when processes need to exchange data without operating in lockstep. Keep the testbench architecture proportional to the complexity of the DUT. A simple testbench may need only two processes and a queue; more elaborate separation is optional.

2. **Use VUnit queues.** Create a queue with `new_queue` and exchange data using the appropriate `push` and `pop` operations. VUnit queues support standard VHDL data types and VUnit-defined types. Do not implement a custom FIFO or shared-variable queue when `queue_t` already meets the need.

3. **Choose what to exchange.** Queue input transactions, expected results, or other information as appropriate. For example, a process driving an input interface may queue the stimulus it applies, leaving another process to calculate the expected output. Alternatively, it may calculate and queue the expected result directly. Choose whichever approach keeps the verification logic simplest and clearest.

4. **Respect transaction semantics.** Enqueue and dequeue data at meaningful points according to the interface protocol. Use the queue's FIFO ordering when that matches the expected behavior. Do not impose ordering requirements on DUTs that do not guarantee ordered results.

5. **Handle queue state correctly.** Use `is_empty` before popping. The `length` function reports the queue size in bytes, not the number of logical transactions. Handle outstanding data and clear stale contents between independent tests or after reset when appropriate.

6. **Synchronize and complete when needed.** A queue stores data but does not itself wake a process waiting for new work. When notification is useful, use VUnit events as described in the `synchronize-processes` skill. When outstanding transactions must be verified before simulation ends, follow the `manage-test-completion` skill to use VUnit test runner phase locks.

7. **Consume queued work promptly.** Prefer event-driven waiting over polling queues at clock edges. Retrieve queued transactions as soon as they become available, independently of when the associated DUT transaction can occur. This applies to processes driving DUT inputs as well as those consuming DUT outputs. Waiting for a clock edge merely to discover queued data can introduce unnecessary latency. Use the interface protocol—not queue availability—to determine when hardware transactions occur.

Consult the [VUnit Queue API](https://vunit.github.io/data_types/queue.html) and [Data Types User Guide](https://vunit.github.io/data_types/user_guide.html).
