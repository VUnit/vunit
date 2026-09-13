/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * Error text of the last failed operation, reported to VHDL.
 */

#include "bridge.h"

#include <stdlib.h>
#include <string.h>

/* UTF-8, owned. Sticky when initialization failed. */
static char *g_error = NULL;
static size_t g_error_length = 0;

void vpy_set_error_bytes(const char *text, size_t length) {
  char *copy = (char *)malloc(length + 1);

  free(g_error);
  g_error = NULL;
  g_error_length = 0;
  if (copy == NULL) {
    return;
  }
  memcpy(copy, text, length);
  copy[length] = '\0';
  g_error = copy;
  g_error_length = length;
}

void vpy_set_error(const char *text) { vpy_set_error_bytes(text, strlen(text)); }

/* prefix may be the current error text, it is copied before being replaced. */
void vpy_set_error2(const char *prefix, const char *detail) {
  size_t prefix_length = strlen(prefix);
  size_t detail_length = detail == NULL ? 0 : strlen(detail);
  char *text = (char *)malloc(prefix_length + detail_length + 1);

  if (text == NULL) {
    vpy_set_error(prefix);
    return;
  }
  memcpy(text, prefix, prefix_length);
  if (detail_length > 0) {
    memcpy(text + prefix_length, detail, detail_length);
  }
  text[prefix_length + detail_length] = '\0';
  vpy_set_error_bytes(text, prefix_length + detail_length);
  free(text);
}

int vpy_has_error(void) { return g_error != NULL; }

/* New reference to the raised exception, which is cleared. NULL if none. */
static PyObject *take_exception(void) {
#if PY_VERSION_HEX >= 0x030C0000
  return PyErr_GetRaisedException();
#else
  PyObject *type, *value, *traceback;

  PyErr_Fetch(&type, &value, &traceback);
  PyErr_NormalizeException(&type, &value, &traceback);
  if (value != NULL && traceback != NULL) {
    PyException_SetTraceback(value, traceback);
  }
  Py_XDECREF(type);
  Py_XDECREF(traceback);
  return value;
#endif
}

/*
 * Convert the currently raised Python exception into the error text and clear
 * it. Formatting is delegated to the runtime, which hides bridge-internal
 * traceback frames; plain str() and a fixed text are the fallbacks.
 */
void vpy_set_error_from_python(void) {
  PyObject *exc = take_exception();
  PyObject *text = NULL;

  if (exc == NULL) {
    vpy_set_error("Unknown Python error (no exception set)");
    return;
  }

  if (vpy_runtime() != NULL) {
    text = PyObject_CallMethod(vpy_runtime(), "format_exception", "O", exc);
    if (text == NULL) {
      PyErr_Clear();
    }
  }
  if (text == NULL) {
    text = PyObject_Str(exc);
    if (text == NULL) {
      PyErr_Clear();
    }
  }

  if (text != NULL && PyUnicode_Check(text)) {
    Py_ssize_t length;
    const char *utf8 = PyUnicode_AsUTF8AndSize(text, &length);

    if (utf8 != NULL) {
      vpy_set_error_bytes(utf8, (size_t)length);
    } else {
      PyErr_Clear();
      vpy_set_error("Python error (message could not be encoded)");
    }
  } else {
    vpy_set_error("Python error (message could not be formatted)");
  }

  Py_XDECREF(text);
  Py_DECREF(exc);
}

VPY_EXPORT int32_t vpy_error_length(void) {
  return g_error_length > INT32_MAX ? INT32_MAX : (int32_t)g_error_length;
}

VPY_EXPORT void vpy_error_read(char *chunk, int32_t offset, int32_t length) {
  if (g_error == NULL || offset < 0 || length <= 0 || (size_t)offset + (size_t)length > g_error_length) {
    return;
  }
  memcpy(chunk, g_error + offset, (size_t)length);
}
