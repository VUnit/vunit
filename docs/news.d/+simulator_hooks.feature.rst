A VUnit package can register simulator hooks with ``register_simulator_hooks`` of the context given to
its setup function. A hook provides extra elaboration flags, extra simulation flags or the environment
of the simulation for one simulator, which is what a package whose HDL code depends on something built
outside the simulator needs to have that found and loaded.
