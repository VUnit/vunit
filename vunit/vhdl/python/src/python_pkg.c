// This package provides a dictionary types and operations
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

#include "python_pkg.h"

static py_error_handler_callback py_error_handler = NULL;
static ffi_error_handler_callback ffi_error_handler = NULL;

void register_py_error_handler(py_error_handler_callback callback) {
  py_error_handler = callback;
}

void register_ffi_error_handler(ffi_error_handler_callback callback) {
  ffi_error_handler = callback;
}

char* get_string(PyObject* pyobj) {
  PyObject* str = PyObject_Str(pyobj);
  if (str == NULL) {
    return NULL;
  }

  PyObject* str_utf_8 = PyUnicode_AsEncodedString(str, "utf-8", NULL);
  Py_DECREF(str);
  if (str_utf_8 == NULL) {
    return NULL;
  }

  char* result = PyBytes_AS_STRING(str_utf_8);
  Py_DECREF(str_utf_8);

  return result;
}

void check_conversion_error(const char* expr) {
  PyObject* exc = PyErr_Occurred();
  if (exc != NULL) {
    Py_DECREF(exc);
    py_error_handler("parsing evaluation result of", expr, NULL, true);
  }
}

void handle_type_check_error(PyObject* pyobj, const char* context,
                             const char* expr) {
  PyObject* type_name = PyType_GetName(Py_TYPE(pyobj));
  if (type_name == NULL) {
    py_error_handler(context, expr, "Expression evaluates to an unknown type.",
                     true);
  }

  const char* type_name_str = get_string(type_name);
  Py_DECREF(type_name);
  if (type_name_str == NULL) {
    py_error_handler(context, expr, "Expression evaluates to an unknown type.",
                     true);
  }

  char error_message[100] = "Expression evaluates to ";
  strncat(error_message, type_name_str, 75);
  py_error_handler(context, expr, error_message, true);
}

PyObject* eval(const char* expr) {
  PyObject* pyobj = PyRun_String(expr, Py_eval_input, globals, locals);
  if (pyobj == NULL) {
    py_error_handler("evaluating", expr, NULL, true);
  }

  return pyobj;
}

int get_integer(PyObject* pyobj, const char* expr, bool dec_ref_count) {
  // Check that the Python object has the correct type
  if (!PyLong_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to integer", expr);
  }

  // Convert from Python-typed to C-typed value and check for any errors such as
  // overflow/underflow
  long value = PyLong_AsLong(pyobj);
  if (dec_ref_count) {
    Py_DECREF(pyobj);
  }
  check_conversion_error(expr);

  // TODO: Assume that the simulator is limited to 32-bits for now
  if ((value > pow(2, 31) - 1) || (value < -pow(2, 31))) {
    py_error_handler("parsing evaluation result of", expr,
                     "Result out of VHDL integer range.", true);
  }

  return (int)value;
}

double get_real(PyObject* pyobj, const char* expr, bool dec_ref_count) {
  // Check that the Python object has the correct type
  if (!PyFloat_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to real", expr);
  }

  // Convert from Python-typed to C-typed value and check for any errors such as
  // overflow/underflow
  double value = PyFloat_AsDouble(pyobj);
  if (dec_ref_count) {
    Py_DECREF(pyobj);
  }
  check_conversion_error(expr);

  // TODO: Assume that the simulator is limited to 32-bits for now
  if ((value > 3.4028234664e38) || (value < -3.4028234664e38)) {
    py_error_handler("parsing evaluation result of", expr,
                     "Result out of VHDL real range.", true);
  }

  return value;
}
