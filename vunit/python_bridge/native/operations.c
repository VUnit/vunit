/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * The operations: setup, cleanup, begin, exec, eval, and the conversion and
 * transfer of the result back to VHDL.
 */

#include "bridge.h"

#include <stdio.h>
#include <string.h>

#define NUM_META 8

/* Result of the last evaluation, converted to a VHDL kind by vpy_eval. */
static PyObject *g_result = NULL; /* bytes of a string/array result, strong reference */
static const char *g_result_data = NULL; /* view into g_result, immutable */
static size_t g_result_size = 0;
static int32_t g_result_integer = 0;
static double g_result_real = 0.0;
static int32_t g_result_meta[NUM_META];

/* Drop the result of the previous operation. GIL held. */
static void clear_result(void) {
  Py_CLEAR(g_result);
  g_result_data = NULL;
  g_result_size = 0;
  g_result_integer = 0;
  g_result_real = 0.0;
  memset(g_result_meta, 0, sizeof(g_result_meta));
}

/* Keep the simulator's and Python's output in order. */
static void flush_c_streams(void) {
  fflush(stdout);
  fflush(stderr);
}

/*
 * Start the interpreter. Eager and idempotent: later calls only re-run the
 * runtime's setup, which does nothing but flush. Optional: every operation
 * starts the interpreter if it is not running, see vpy_begin.
 */
VPY_EXPORT int32_t vpy_setup(void) {
  PyGILState_STATE gil;
  int status;

  flush_c_streams();
  if (vpy_initialize() != VPY_OK || vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  status = vpy_finish_call(PyObject_CallMethod(vpy_runtime(), "setup", NULL));
  PyGILState_Release(gil);
  return status;
}

/*
 * Release what the simulation acquired: flush Python's streams and drop the
 * last result and the staged values. The interpreter is NOT finalized and the
 * session namespaces are kept, so later operations keep working. Optional:
 * everything it releases is released by the simulator process ending, and
 * every operation flushes on its own.
 */
VPY_EXPORT int32_t vpy_cleanup(void) {
  PyGILState_STATE gil;
  int status;

  flush_c_streams();
  if (!vpy_is_initialized()) {
    /* Nothing was ever started, so there is nothing to release. */
    return VPY_OK;
  }
  if (vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  clear_result();
  vpy_clear_arguments();
  status = vpy_finish_call(PyObject_CallMethod(vpy_runtime(), "cleanup", NULL));
  PyGILState_Release(gil);
  return status;
}

/*
 * Start a new operation in the session named by the buffer: initialize on
 * first use, select the session and drop the previous result and values.
 */
VPY_EXPORT int32_t vpy_begin(void) {
  PyGILState_STATE gil;
  PyObject *session;
  int status = VPY_ERROR;

  if (vpy_initialize() != VPY_OK || vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  clear_result();
  vpy_clear_arguments();
  session = vpy_buffer_as_str();
  if (session == NULL) {
    vpy_set_error_from_python();
  } else {
    status = vpy_finish_call(PyObject_CallMethod(vpy_runtime(), "select_session", "O", session));
    Py_DECREF(session);
  }
  PyGILState_Release(gil);
  return status;
}

/* Execute the buffer as Python source (is_file = 0) or as a file name (is_file = 1). */
VPY_EXPORT int32_t vpy_execute(int32_t is_file) {
  PyGILState_STATE gil;
  PyObject *text;
  int status = VPY_ERROR;

  flush_c_streams();
  if (vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  text = vpy_buffer_as_str();
  if (text == NULL) {
    vpy_set_error_from_python();
  } else {
    status = vpy_finish_call(PyObject_CallMethod(vpy_runtime(), "execute", "Oi", text, (int)(is_file != 0)));
    Py_DECREF(text);
  }
  PyGILState_Release(gil);
  /* The runtime flushed Python's streams, flush what Python wrote through C */
  flush_c_streams();
  return status;
}

/*
 * Store the conversion result (integer, real, bytes, meta tuple) returned by
 * the runtime. Which fields are meaningful depends on the kind. GIL held.
 */
static int store_result(PyObject *converted) {
  PyObject *data;
  PyObject *meta;
  Py_ssize_t index;

  if (!PyTuple_Check(converted) || PyTuple_Size(converted) != 4) {
    vpy_set_error("Internal error: unexpected result conversion format");
    return VPY_ERROR;
  }
  data = PyTuple_GetItem(converted, 2); /* borrowed */
  meta = PyTuple_GetItem(converted, 3); /* borrowed */
  if (!PyBytes_Check(data) || !PyTuple_Check(meta)) {
    vpy_set_error("Internal error: unexpected result conversion format");
    return VPY_ERROR;
  }

  g_result_integer = (int32_t)PyLong_AsLong(PyTuple_GetItem(converted, 0));
  g_result_real = PyFloat_AsDouble(PyTuple_GetItem(converted, 1));
  for (index = 0; index < PyTuple_Size(meta) && index < NUM_META; index++) {
    g_result_meta[index] = (int32_t)PyLong_AsLong(PyTuple_GetItem(meta, index));
  }
  if (PyErr_Occurred()) {
    vpy_set_error_from_python();
    return VPY_ERROR;
  }

  Py_INCREF(data);
  g_result = data;
  g_result_data = PyBytes_AsString(data);
  g_result_size = (size_t)PyBytes_Size(data);
  return VPY_OK;
}

/*
 * Evaluate the buffer as a Python expression in the current session and
 * convert the value to the requested VHDL kind and width.
 */
VPY_EXPORT int32_t vpy_eval(int32_t kind, int32_t width) {
  PyGILState_STATE gil;
  PyObject *text;
  PyObject *converted;
  int status = VPY_ERROR;

  flush_c_streams();
  if (vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  clear_result();
  text = vpy_buffer_as_str();
  if (text == NULL) {
    vpy_set_error_from_python();
  } else {
    converted = PyObject_CallMethod(vpy_runtime(), "evaluate", "Oii", text, (int)kind, (int)width);
    Py_DECREF(text);
    if (converted == NULL) {
      vpy_set_error_from_python();
    } else {
      status = store_result(converted);
      Py_DECREF(converted);
    }
  }
  if (status != VPY_OK) {
    clear_result();
  }
  PyGILState_Release(gil);
  /* The runtime flushed Python's streams, flush what Python wrote through C */
  flush_c_streams();
  return status;
}

VPY_EXPORT int32_t vpy_result_integer(void) { return g_result_integer; }

VPY_EXPORT double vpy_result_real(void) { return g_result_real; }

VPY_EXPORT int32_t vpy_result_meta(int32_t index) {
  if (index < 0 || index >= NUM_META) {
    return 0;
  }
  return g_result_meta[index];
}

/* Copy length bytes of the string/bit-string result starting at offset. */
VPY_EXPORT void vpy_result_read_string(char *chunk, int32_t offset, int32_t length) {
  if (offset < 0 || length <= 0 || (size_t)offset + (size_t)length > g_result_size) {
    return;
  }
  memcpy(chunk, g_result_data + offset, (size_t)length);
}

/* Copy length integers of an integer_array_t/integer_vector result starting at element offset. */
VPY_EXPORT void vpy_result_read_integers(int32_t *chunk, int32_t offset, int32_t length) {
  size_t start = (size_t)offset * sizeof(int32_t);
  size_t bytes = (size_t)length * sizeof(int32_t);

  if (offset < 0 || length <= 0 || start + bytes > g_result_size) {
    return;
  }
  memcpy(chunk, g_result_data + start, bytes);
}

/* Copy length reals of a real_vector result starting at element offset. */
VPY_EXPORT void vpy_result_read_reals(double *chunk, int32_t offset, int32_t length) {
  size_t start = (size_t)offset * sizeof(double);
  size_t bytes = (size_t)length * sizeof(double);

  if (offset < 0 || length <= 0 || start + bytes > g_result_size) {
    return;
  }
  memcpy(chunk, g_result_data + start, bytes);
}
