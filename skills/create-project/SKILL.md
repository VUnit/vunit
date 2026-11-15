---
name: create-project
description: Create or integrate a VUnit project for VHDL verification. Use when setting up VUnit in a new or existing HDL project, generating a VUnit run script, or configuring existing HDL sources for VUnit.
license: MPL-2.0
---

# Create a VUnit Project

1. **Inspect the project.** Determine whether this is a new project or an existing HDL repository. Identify relevant VHDL sources, their library assignments, existing testbenches, and established build or simulation conventions. When all sources belong to a single library, prefer VUnit's default library name (`lib`). VHDL references to `work` refer to the library in which each source is compiled; they do not imply a physical library named `work`. **Never create a VUnit library named `work`**, which VUnit does not permit. Preserve other explicitly required library names.

2. **Check for existing VUnit configuration.** Look for an existing `run.py` or other VUnit entry point. Prefer extending a working setup over generating a competing one. Do not overwrite project files without authorization.

3. **Generate the project.** Run `vunit create-project --help` to discover the current interface. Use the deterministic generator rather than writing project scaffolding manually. Pass discovered source mappings using `--source` and `--recursive-source` as appropriate. Use `--library` only when additional or explicitly named libraries are needed. Never pass `work` as the library name to any of these options. Use `--preview` to review planned changes before generating files.

4. **Respect existing project conventions.** Preserve the established source layout and library assignments. Use VUnit's existing dependency handling rather than implementing custom compilation-order logic. Make targeted adjustments only when the generator cannot express an existing project requirement.

5. **Validate.** Run the generated VUnit project to compile its sources and execute any existing tests. Investigate failures and distinguish project configuration issues from existing HDL defects. Let VUnit handle simulator discovery and availability.

6. **Report the result.** Summarize the generated files, configured libraries and source paths, and validation results. Identify any unresolved issues.

Keep changes focused on VUnit project setup. Do not reorganize RTL, add unrelated infrastructure, or modify existing verification logic unless explicitly requested.