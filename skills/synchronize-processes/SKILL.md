---
name: synchronize-processes
description: Synchronize concurrent VHDL testbench processes using VUnit events. Use when processes need to notify each other about new work, available data, or other activity, for example in stimulus generation, interface driving, or result checking.
license: MPL-2.0
---

# Synchronize Processes with VUnit Events

1. **Use events for notifications.** VUnit provides `event_t`, `new_event`, `notify`, and `is_active` for coordination between concurrent VHDL processes. Declare events as signals. Use events to indicate that something has happened rather than inventing custom notification signals.

2. **Understand event semantics.** Events are transient notifications, not stored state. A process that begins waiting after an event has occurred will not receive that earlier notification. Do not assume an event remains pending until consumed.

3. **Combine events with persistent conditions.** When notifying a process about queued data, store the data in a queue and use an event to wake the consumer. Always check whether data is already available before waiting.

   For example, a transaction containing an address, data, and a read/write flag can be exchanged as three queued values:

   ```vhdl
   -- Architecture declarations
   constant work_queue : queue_t := new_queue;
   signal work_available : event_t := new_event;

   -- Producer process
   push(work_queue, address);
   push(work_queue, data);
   push(work_queue, is_write);
   notify(work_available);

   -- Consumer process
   if is_empty(work_queue) then
     wait until is_active(work_available);
   end if;

   address  := pop_integer(work_queue);
   data     := pop_std_ulogic_vector(work_queue);
   is_write := pop_boolean(work_queue);
   ```

   This example assumes `address` is an integer, `data` is a logic vector, and `is_write` is a boolean. VUnit queues support many standard VHDL types as well as VUnit-defined types. A logical transaction can consist of one or several queued values, provided the producer and consumer agree on their order and types.

   The queue preserves the data even if an earlier notification was missed. Notify after all values belonging to the transaction have been queued. For multiple queued transactions, continue processing until the queue is empty.

4. **Avoid synchronization races.** Do not wait unconditionally for an event when the condition being awaited might already be true. Do not rely on events to remember outstanding work. Use a queue or another persistent condition to track work that must still be processed. Consider reset, repeated tests, and the relative timing of concurrent processes.

5. **Avoid clock-driven polling for queued work.** When a process needs queued data, check whether the queue is nonempty and otherwise wait for the event notifying it of new data. This allows the process to respond without introducing an additional clock-cycle delay. Clock edges remain appropriate for protocol-specific operations.

6. **Keep interface monitoring independent.** A process checking a hardware interface should continue observing the relevant clock edges and transactions. Do not let event-based waiting hide unexpected DUT activity. Use events to coordinate testbench work, not to replace verification of hardware handshakes.

7. **Separate notifications from test completion.** Events notify processes about activity but do not guarantee that all outstanding work has finished. When a test must wait for concurrent verification processes to complete, follow the `manage-test-completion` skill and use VUnit test runner phase locks rather than relying on completion events or fixed delays.

Consult the [VUnit Events User Guide](https://vunit.github.io/data_types/event_user_guide.html) and [VUnit Events blog](https://vunit.github.io/blog/2023_03_31_vunit_events.html). For test completion, see the [VUnit Phases blog](https://vunit.github.io/blog/2023_04_01_vunit_phases.html).