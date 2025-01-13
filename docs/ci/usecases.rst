.. _continuous_integration:usecases:

Practical use cases
###################

Workflow `tests.yml <https://github.com/VUnit/tdd-intro/blob/master/.github/workflows/tests.yml>`_ from repo `VUnit/tdd-intro <https://github.com/VUnit/tdd-intro>`_
showcases five procedures to setup continuous integration in GitHub Actions, using GHDL and VUnit as a regression framework.
The entrypoint to all the jobs is the same `pytest <https://pytest.org>`_ script (`test.py <https://github.com/VUnit/tdd-intro/blob/master/test.py>`_),
thus, all jobs are equivalent solutions. Tests called through pytest can be defined in any language: VUnit run.py scripts,
bash/shell scripts, makefiles, etc.

It is suggested for new users to clone/fork this template repository, and then remove the jobs they don't want to use. Since
all are equivalent, using a single job is enough to have HDL designs tested. However, it might be useful to have designs
tested on different platforms.

lin-vunit
*********

Uses *Docker Action* `VUnit/vunit_action <https://github.com/VUnit/vunit_action>`_, based on image ``ghdl/vunit:llvm`` (see
`ghdl/docker: VUnit <https://github.com/ghdl/docker#-vunit-1-job-6-images-triggered-after-workflow-buster>`_). It takes a
single optional argument: the path to the ``run.py``. See `VUnit/vunit_action: README.md <https://github.com/VUnit/vunit_action/blob/master/README.md>`_
for further info.

This is the most straightforward solution, and the one with fastest startup.

lin-docker
**********

Docker based job, which can be used in any CI system. An (optional) `Dockerfile <https://github.com/VUnit/tdd-intro/blob/master/.github/Dockerfile>`_ is used to add some packages on top of image ``ghdl/vunit:llvm`` (see :ref:`continuous_integration:container:customizing`). However, the same procedure can be used with any other image.

This is equivalent to *lin-vunit*, but it is slightly more verbose.

lin-setup
*********

Uses *JavaScript Action* `ghdl/setup-ghdl <https://github.com/ghdl/setup-ghdl>`_ to install GHDL on the Ubuntu host/VM.
Then, additional system packages and Python packages are installed explicitly.

Compared to previous approaches, in this case runtime dependencies are not pre-installed. As a result, startup is slightly
slower.

win-setup
*********

Uses Actions `ghdl/setup-ghdl <https://github.com/ghdl/setup-ghdl>`_ and `msys2/setup-msys2 <https://github.com/msys2/setup-msys2>`_
to install latest *nightly* GHDL, other MSYS2 packages and Python packages in a *clean* MINGW64 environment.

This is the recommended approach to run tests on Windows. Action setup-msys2 caches installed packages/dependencies
automatically.

win-stable
**********

The *traditional* procedure of downloading a tarball/zipfile from GHDL's latest *stable* release. Additional Python packages
are installed explicitly.

This is more verbose than the previous approach, but it's currently the only solution to use latest *stable* GHDL without
building it from sources.

Repositories using VUnit for CI
*******************************

This is a non-exhaustive list of projects where VUnit is used for testing HDL designs:

* `VUnit/vunit <https://github.com/VUnit/vunit>`_
* `ghdl/ghdl-cosim <https://github.com/ghdl/ghdl-cosim>`_
