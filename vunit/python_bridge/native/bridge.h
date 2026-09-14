/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * Internal header of the native bridge between VHDL and an embedded CPython
 * interpreter. The bridge is a private implementation detail of
 * python_ffi_pkg: VHDL builds Python source text and the bridge executes or
 * evaluates it. VHDL reaches the entry points below through VHPIDIRECT on NVC
 * and GHDL and through the FLI front end in fli.c on Questa/ModelSim.
 *
 * Modules:
 *   error.c        error text reported to VHDL
 *   config.c       configuration file written by VUnit next to the library
 *   interpreter.c  starting the interpreter and loading ../runtime.py
 *   arguments.c    strings and integer_array_t values transferred from VHDL
 *   operations.c   setup, exec, eval and results transferred back to VHDL
 *   fli.c          Questa/ModelSim front end, only built for that simulator
 *
 * ABI rules, chosen to be identical for NVC and GHDL on all platforms, and
 * translated to the FLI parameter passing conventions by fli.c:
 *   - VHDL integer <-> int32_t, VHDL real <-> double.
 *   - Booleans are passed as integers (0/1), never as VHDL boolean.
 *   - Strings and integer vectors only cross the boundary as *constrained*
 *     chunks (plain pointers) with explicit offsets/lengths. Unconstrained
 *     arrays (fat pointers) are simulator specific and are never used.
 *   - Every operation that can fail returns a status (VPY_OK or VPY_ERROR).
 *     The error text is retrieved with vpy_error_length/vpy_error_read.
 *
 * Python objects are only touched with the GIL held. Python data symbols
 * (e.g. Py_None) must not be used: the Windows DLL delay-loads the Python
 * DLL, which only supports functions.
 */

#ifndef VUNIT_PYTHON_BRIDGE_H
#define VUNIT_PYTHON_BRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#include <stddef.h>
#include <stdint.h>

#ifdef Py_GIL_DISABLED
#error "VHDL Python support does not work with free-threaded CPython builds"
#endif

#ifdef _WIN32
#define VPY_EXPORT __declspec(dllexport)
#else
#define VPY_EXPORT __attribute__((visibility("default")))
#endif

#define VPY_OK 0
#define VPY_ERROR 1

/*
 * Entry points called from VHDL (declared in python_bridge_pkg.vhd.in,
 * directly for VHPIDIRECT and through the fli_ prefixed wrappers of fli.c for
 * the FLI). Strings cross the boundary through a buffer; integer_array_t
 * values are pushed and staged, everything else is Python source text built
 * by VHDL.
 */
VPY_EXPORT int32_t vpy_setup(void);
VPY_EXPORT int32_t vpy_cleanup(void);
VPY_EXPORT int32_t vpy_buffer_clear(void);
VPY_EXPORT int32_t vpy_buffer_append(const char *chunk, int32_t length);
VPY_EXPORT int32_t vpy_begin(void);
VPY_EXPORT int32_t vpy_execute(int32_t is_file);
VPY_EXPORT int32_t vpy_eval(int32_t kind, int32_t width);
VPY_EXPORT int32_t vpy_push_array(int32_t length, int32_t width, int32_t height, int32_t depth, int32_t bit_width,
                                  int32_t is_signed);
VPY_EXPORT int32_t vpy_array_write(const int32_t *chunk, int32_t length);
VPY_EXPORT int32_t vpy_stage(void);
VPY_EXPORT int32_t vpy_result_integer(void);
VPY_EXPORT double vpy_result_real(void);
VPY_EXPORT int32_t vpy_result_meta(int32_t index);
VPY_EXPORT void vpy_result_read_string(char *chunk, int32_t offset, int32_t length);
VPY_EXPORT void vpy_result_read_integers(int32_t *chunk, int32_t offset, int32_t length);
VPY_EXPORT void vpy_result_read_reals(double *chunk, int32_t offset, int32_t length);
VPY_EXPORT int32_t vpy_error_length(void);
VPY_EXPORT void vpy_error_read(char *chunk, int32_t offset, int32_t length);

/* Internal functions shared between the modules */

/* error.c */
void vpy_set_error(const char *text);
void vpy_set_error_bytes(const char *text, size_t length);
void vpy_set_error2(const char *prefix, const char *detail);
void vpy_set_error_from_python(void); /* GIL held */
int vpy_has_error(void);

/* config.c */
typedef struct {
  char *executable;     /* sys.executable of the Python running VUnit */
  char *prefix;         /* its sys.prefix, verified by the runtime */
  char *runtime;        /* path of runtime.py */
  char *run_script_dir; /* directory of the run script, put on sys.path */
  char *python_dll;     /* Windows only: path of the Python DLL */
} vpy_config_t;

int vpy_read_config(vpy_config_t *config);

/* interpreter.c */
int vpy_initialize(void);
int vpy_is_initialized(void);
PyObject *vpy_runtime(void); /* borrowed, NULL before initialization */
int vpy_enter(PyGILState_STATE *gil);
int vpy_finish_call(PyObject *ret); /* GIL held, steals ret */

/* arguments.c (GIL held) */
PyObject *vpy_buffer_as_str(void);
void vpy_clear_arguments(void);

#endif
