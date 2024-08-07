// This package provides a dictionary types and operations
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

#include "python_pkg.h"

PyObject* globals = NULL;
PyObject* locals = NULL;

#define MAX_VHDL_PARAMETER_STRING_LENGTH 100000

void python_cleanup(void);

static void py_error_handler(const char* context, const char* code_or_expr,
                             const char* reason, bool cleanup) {
  const char* unknown_error = "Unknown error";

  // Use provided error reason or try extracting the reason from the Python
  // exception
  if (reason == NULL) {
    PyObject *ptype, *pvalue, *ptraceback;
    PyErr_Fetch(&ptype, &pvalue, &ptraceback);
    if (ptype != NULL) {
      reason = get_string(pvalue);
    }
    PyErr_Restore(ptype, pvalue, ptraceback);
  }

  // Clean-up Python session first in case vhpi_assert stops the simulation
  if (cleanup) {
    python_cleanup();
  }

  // Output error message
  reason = reason == NULL ? unknown_error : reason;
  if (code_or_expr == NULL) {
    printf("ERROR %s:\n\n%s\n\n", context, reason);
  } else {
    printf("ERROR %s:\n\n%s\n\n%s\n\n", context, code_or_expr, reason);
  }
  assert(0);
}

static void ffi_error_handler(const char* context, bool cleanup) {
  // Clean-up Python session first in case vhpi_assert stops the simulation
  if (cleanup) {
    python_cleanup();
  }

  printf("ERROR %s\n\n", context);
  assert(0);
}

void python_setup(void) {
  Py_Initialize();
  if (!Py_IsInitialized()) {
    ffi_error_handler("Failed to initialize Python", false);
  }

  PyObject* main_module = PyImport_AddModule("__main__");
  if (main_module == NULL) {
    ffi_error_handler("Failed to get the main module", true);
  }

  globals = PyModule_GetDict(main_module);
  if (globals == NULL) {
    ffi_error_handler("Failed to get the global dictionary", true);
  }

  // globals and locals are the same at the top-level
  locals = globals;

  register_py_error_handler(py_error_handler);
  register_ffi_error_handler(ffi_error_handler);

  // This class allow us to evaluate an expression and get the length of the
  // result before getting the result. The length is used to allocate a VHDL
  // array before getting the result. This saves us from passing and evaluating
  // the expression twice (both when getting its length and its value). When
  // only supporting Python 3.8+, this can be solved with the walrus operator:
  // len(__eval_result__ := expr)
  char* code =
      "\
class __EvalResult__():\n\
    def __init__(self):\n\
        self._result = None\n\
    def set(self, expr):\n\
        self._result = expr\n\
        return len(self._result)\n\
    def get(self):\n\
        return self._result\n\
__eval_result__=__EvalResult__()\n";


  if (PyRun_String(code, Py_file_input, globals, locals) == NULL) {
    ffi_error_handler("Failed to initialize predefined Python objects", true);
  }
}

void python_cleanup(void) {
  if (locals != NULL) {
    Py_DECREF(locals);
  }


  if (Py_FinalizeEx()) {
    printf("WARNING: Failed to finalize Python\n");
  }
}

static const char* get_parameter(const char* expr, int64_t length) {
  static char vhdl_parameter_string[MAX_VHDL_PARAMETER_STRING_LENGTH];

  memcpy(vhdl_parameter_string, expr, sizeof(char) * length);
  vhdl_parameter_string[length] = '\0';

  return vhdl_parameter_string;
}

int eval_integer(const char* expr, int64_t length) {
  // Get null-terminated expression parameter from VHDL function call
  const char *param = get_parameter(expr, length);

  // Eval(uate) expression in Python
  PyObject* eval_result = eval(param);

  // Return result to VHDL
  return get_integer(eval_result, param, true);
}

double eval_real(const char* expr, int64_t length) {
  // Get null-terminated expression parameter from VHDL function call
  const char *param = get_parameter(expr, length);

  // Eval(uate) expression in Python
  PyObject* eval_result = eval(param);

  // Return result to VHDL
  return get_real(eval_result, param, true);
}

void get_integer_vector(int* vec, int64_t length) {
  // Get evaluation result from Python
  PyObject* eval_result = eval("__eval_result__.get()");

  // Check that the eval results in a list. TODO: tuple and sets of integers
  // should also work
  if (!PyList_Check(eval_result)) {
    handle_type_check_error(eval_result, "evaluating to integer_vector",
                            "__eval_result__.get()");
  }

  for (int idx = 0; idx < length; idx++) {
    vec[idx] = get_integer(PyList_GetItem(eval_result, idx),
                           "__eval_result__.get()", false);
  }
  Py_DECREF(eval_result);
}

void get_real_vector(double* vec, int64_t length) {
  // Get evaluation result from Python
  PyObject* eval_result = eval("__eval_result__.get()");

  // Check that the eval results in a list. TODO: tuple and sets of integers
  // should also work
  if (!PyList_Check(eval_result)) {
    handle_type_check_error(eval_result, "evaluating to real_vector",
                            "__eval_result__.get()");
  }

  for (int idx = 0; idx < length; idx++) {
    vec[idx] = get_real(PyList_GetItem(eval_result, idx),
                           "__eval_result__.get()", false);
  }
  Py_DECREF(eval_result);
}

void get_py_string(char* vec, int64_t length) {
  // Get evaluation result from Python
  PyObject* eval_result = eval("__eval_result__.get()");

  const char* py_str = get_string(eval_result);
  strcpy(vec, py_str);

  Py_DECREF(eval_result);
}

void exec(const char* code, int64_t length) {
  // Get null-terminated code parameter from VHDL function call
  const char *param = get_parameter(code, length);

  // Exec(ute) Python code
  if (PyRun_String(param, Py_file_input, globals, locals) == NULL) {
    py_error_handler("executing", param, NULL, true);
  }
}

void (*vhpi_startup_routines[])() = {
   NULL
};
