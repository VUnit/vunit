A VUnit package can provide a setup function with the ``setup`` key of its ``vunit_pkg.toml`` file.
The function is called with a :class:`PackageContext <vunit.package_context.PackageContext>` once the
sources of the package have been added and allows a package to do work that cannot be expressed with
static sources, such as building a native library or adding generated sources.
