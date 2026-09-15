/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * Data transferred from VHDL: a byte buffer for strings (Python source code,
 * expressions, file and session names) and the integer_array_t value being
 * pushed, which is staged in the runtime and then referred to from the Python
 * source text VHDL builds.
 */

#include "bridge.h"

#include <stdlib.h>
#include <string.h>

/* Raw byte buffer used to transfer strings from VHDL, owned. */
static char *g_buffer = NULL;
static size_t g_buffer_length = 0;
static size_t g_buffer_capacity = 0;

/* Strong references, only touched with the GIL held. */
static PyObject *g_array = NULL;   /* NumPy array of the integer_array_t being pushed */
static PyObject *g_pending = NULL; /* bytearray backing it */

/* View into g_pending. It is owned by us and never resized while referenced
 * (NumPy holds a buffer export on it), so the pointer stays valid. */
static char *g_pending_data = NULL;
static size_t g_pending_size = 0;
static size_t g_pending_position = 0;

/* New reference to the transfer buffer as a str. */
PyObject *vpy_buffer_as_str(void) {
  return PyUnicode_DecodeUTF8(g_buffer == NULL ? "" : g_buffer, (Py_ssize_t)g_buffer_length, "surrogateescape");
}

void vpy_clear_arguments(void) {
  Py_CLEAR(g_array);
  Py_CLEAR(g_pending);
  g_pending_data = NULL;
  g_pending_size = 0;
  g_pending_position = 0;
}

/* ------------------------------------------------------------------------ */
/* Entry points                                                              */
/* ------------------------------------------------------------------------ */

VPY_EXPORT int32_t vpy_buffer_clear(void) {
  g_buffer_length = 0;
  return VPY_OK;
}

VPY_EXPORT int32_t vpy_buffer_append(const char *chunk, int32_t length) {
  size_t required;

  if (length <= 0) {
    return VPY_OK;
  }
  required = g_buffer_length + (size_t)length;
  if (required > g_buffer_capacity) {
    size_t capacity = g_buffer_capacity == 0 ? 4096 : g_buffer_capacity;
    char *buffer;

    while (capacity < required) {
      capacity *= 2;
    }
    buffer = (char *)realloc(g_buffer, capacity);
    if (buffer == NULL) {
      vpy_set_error("Out of memory while transferring a string to Python");
      return VPY_ERROR;
    }
    g_buffer = buffer;
    g_buffer_capacity = capacity;
  }
  memcpy(g_buffer + g_buffer_length, chunk, (size_t)length);
  g_buffer_length = required;
  return VPY_OK;
}

/*
 * Push an integer_array_t value. Allocates the Python-owned storage that the
 * element values are subsequently written to with vpy_array_write. The value
 * is made available to Python source code by vpy_stage.
 */
VPY_EXPORT int32_t vpy_push_array(int32_t length, int32_t width, int32_t height, int32_t depth, int32_t bit_width,
                                  int32_t is_signed) {
  PyGILState_STATE gil;
  size_t size = length > 0 ? (size_t)length * sizeof(int32_t) : 0;
  PyObject *storage = NULL;
  int status = VPY_ERROR;

  if (vpy_initialize() != VPY_OK || vpy_enter(&gil) != VPY_OK) {
    return VPY_ERROR;
  }
  vpy_clear_arguments();
  if (length < 0) {
    vpy_set_error("Internal error: negative array length");
    goto done;
  }

  storage = PyByteArray_FromStringAndSize(NULL, (Py_ssize_t)size);
  if (storage == NULL) {
    vpy_set_error_from_python();
    goto done;
  }
  if (size > 0) {
    memset(PyByteArray_AsString(storage), 0, size);
  }

  g_array = PyObject_CallMethod(vpy_runtime(), "make_array", "Oiiiiii", storage, (int)length, (int)width, (int)height,
                                (int)depth, (int)bit_width, (int)(is_signed != 0));
  if (g_array == NULL) {
    vpy_set_error_from_python();
    goto done;
  }

  /* The array keeps the storage alive; we keep our own reference too so the
   * cached data pointer is valid until the next vpy_clear_arguments(). */
  g_pending = storage;
  storage = NULL;
  g_pending_data = PyByteArray_AsString(g_pending);
  g_pending_size = size;
  g_pending_position = 0;
  status = VPY_OK;

done:
  Py_XDECREF(storage);
  PyGILState_Release(gil);
  return status;
}

VPY_EXPORT int32_t vpy_array_write(const int32_t *chunk, int32_t length) {
  size_t bytes;

  if (length <= 0) {
    return VPY_OK;
  }
  bytes = (size_t)length * sizeof(int32_t);
  if (g_pending_data == NULL || g_pending_position + bytes > g_pending_size) {
    vpy_set_error("Internal error: array data written out of bounds");
    return VPY_ERROR;
  }
  memcpy(g_pending_data + g_pending_position, chunk, bytes);
  g_pending_position += bytes;
  return VPY_OK;
}

/*
 * Stage the pushed array in the runtime. Python source code built by VHDL
 * refers to it as __vunit__.staged(<id>).
 *
 * Returns the id (>= 1) or -1 on failure, with the error text set.
 */
VPY_EXPORT int32_t vpy_stage(void) {
  PyGILState_STATE gil;
  PyObject *id;
  long value;
  int32_t result = -1;

  if (vpy_initialize() != VPY_OK || vpy_enter(&gil) != VPY_OK) {
    return -1;
  }
  if (g_array == NULL) {
    vpy_set_error("Internal error: no value pushed before vpy_stage");
    goto done;
  }
  id = PyObject_CallMethod(vpy_runtime(), "stage_value", "O", g_array);
  if (id == NULL) {
    vpy_set_error_from_python();
    goto done;
  }
  value = PyLong_AsLong(id);
  Py_DECREF(id);
  if (PyErr_Occurred()) {
    vpy_set_error_from_python();
    goto done;
  }
  if (value < 1 || value > INT32_MAX) {
    vpy_set_error("Internal error: invalid staged value id");
    goto done;
  }
  result = (int32_t)value;

done:
  vpy_clear_arguments();
  PyGILState_Release(gil);
  return result;
}
