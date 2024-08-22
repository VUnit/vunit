// This package provides a dictionary types and operations
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

#include <aldecpli.h>
#include <stdbool.h>
#include <vhpi_user.h>

#include "python_pkg.h"

PyObject* globals = NULL;
PyObject* locals = NULL;

#define MAX_VHDL_PARAMETER_STRING_LENGTH 100000

PLI_VOID python_cleanup(const struct vhpiCbDataS* cb_p);

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
    python_cleanup(NULL);
  }

  // Output error message
  reason = reason == NULL ? unknown_error : reason;
  if (code_or_expr == NULL) {
    vhpi_assert(vhpiError, "ERROR %s:\n\n%s\n\n", context, reason);
  } else {
    vhpi_assert(vhpiError, "ERROR %s:\n\n%s\n\n%s\n\n", context, code_or_expr,
                reason);
  }

  // Stop the simulation if vhpi_assert didn't.
  vhpi_control(vhpiStop);
}

static void ffi_error_handler(const char* context, bool cleanup) {
  vhpiErrorInfoT err;

  // Clean-up Python session first in case vhpi_assert stops the simulation
  if (cleanup) {
    python_cleanup(NULL);
  }

  if (vhpi_check_error(&err)) {
    vhpi_assert(err.severity, "ERROR %s: \n\n%s (%d): %s\n\n", context,
                err.file, err.line, err.message);

  } else {
    vhpi_assert(vhpiError, "ERROR %s\n\n", context);
  }

  // Stop the simulation if vhpi_assert didn't.
  vhpi_control(vhpiStop);
}

PLI_VOID python_setup(const struct vhpiCbDataS* cb_p) {
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
}

PLI_VOID python_cleanup(const struct vhpiCbDataS* cb_p) {
  if (locals != NULL) {
    Py_DECREF(locals);
  }

  if (Py_FinalizeEx()) {
    vhpi_assert(vhpiWarning, "WARNING: Failed to finalize Python");
  }
}

static const char* get_parameter(const struct vhpiCbDataS* cb_p) {
  // Get parameter from VHDL function call
  vhpiHandleT parameter_handle =
      vhpi_handle_by_index(vhpiParamDecls, cb_p->obj, 0);
  if (parameter_handle == NULL) {
    ffi_error_handler("getting VHDL parameter handle", true);
  }

  vhpiValueT parameter;
  static char vhdl_parameter_string[MAX_VHDL_PARAMETER_STRING_LENGTH];

  parameter.bufSize = MAX_VHDL_PARAMETER_STRING_LENGTH;
  parameter.value.str = vhdl_parameter_string;
  parameter.format = vhpiStrVal;

  if (vhpi_get_value(parameter_handle, &parameter)) {
    ffi_error_handler("getting VHDL parameter value", true);
  }

  return vhdl_parameter_string;
}

PLI_VOID eval_integer(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* eval_result = eval(expr);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiIntVal;
  vhdl_result.bufSize = 0;
  vhdl_result.value.intg = get_integer(eval_result, expr, true);
  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr, NULL, true);
  }
}

PLI_VOID eval_real(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* eval_result = eval(expr);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiRealVal;
  vhdl_result.bufSize = 0;
  vhdl_result.value.real = get_real(eval_result, expr, true);
  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr, NULL, true);
  }
}

PLI_VOID eval_integer_vector(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* pyobj = eval(expr);

  // Check that the eval results in a list. TODO: tuple and sets of integers
  // should also work
  if (!PyList_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to integer_vector", expr);
  }

  const int list_size = PyList_GET_SIZE(pyobj);
  const int n_bytes = list_size * sizeof(int);
  int* int_array = (int*)malloc(n_bytes);

  for (int idx = 0; idx < list_size; idx++) {
    int_array[idx] = get_integer(PyList_GetItem(pyobj, idx), expr, false);
  }
  Py_DECREF(pyobj);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiIntVecVal;
  vhdl_result.bufSize = n_bytes;
  vhdl_result.numElems = list_size;
  vhdl_result.value.intgs = (vhpiIntT*)int_array;

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiSizeConstraint)) {
    free(int_array);
    py_error_handler(
        "setting size constraints when returning result for evaluation of",
        expr, NULL, true);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    free(int_array);
    py_error_handler("returning result for evaluation of", expr, NULL, true);
  }

  free(int_array);
}

PLI_VOID eval_real_vector(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* pyobj = eval(expr);

  // Check that the eval results in a list. TODO: tuple and sets of integers
  // should also work
  if (!PyList_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to real_vector", expr);
  }

  const int list_size = PyList_GET_SIZE(pyobj);
  const int n_bytes = list_size * sizeof(double);
  double* double_array = (double*)malloc(n_bytes);

  for (int idx = 0; idx < list_size; idx++) {
    double_array[idx] = get_real(PyList_GetItem(pyobj, idx), expr, false);
  }
  Py_DECREF(pyobj);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiRealVecVal;
  vhdl_result.bufSize = n_bytes;
  vhdl_result.numElems = list_size;
  vhdl_result.value.reals = double_array;

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiSizeConstraint)) {
    free(double_array);
    py_error_handler(
        "setting size constraints when returning result for evaluation of",
        expr, NULL, true);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    free(double_array);
    py_error_handler("returning result for evaluation of", expr, NULL, true);
  }

  free(double_array);
}

PLI_VOID eval_string(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* pyobj = eval(expr);

  char* str = get_string(pyobj);
  Py_DECREF(pyobj);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiStrVal;
  vhdl_result.bufSize = strlen(str) + 1;  // null termination included
  vhdl_result.numElems = strlen(str);
  vhdl_result.value.str = str;

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiSizeConstraint)) {
    py_error_handler(
        "setting size constraints when returning result for evaluation of",
        expr, NULL, true);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr, NULL, true);
  }
}

PLI_VOID exec(const struct vhpiCbDataS* cb_p) {
  // Get code parameter from VHDL procedure call
  const char* code = get_parameter(cb_p);

  // Exec(ute) Python code
  if (PyRun_String(code, Py_file_input, globals, locals) == NULL) {
    py_error_handler("executing", code, NULL, true);
  }
}

PLI_VOID register_foreign_subprograms() {
  char library_name[] = "python";

  char python_setup_name[] = "python_setup";
  vhpiForeignDataT python_setup_data = {vhpiProcF, library_name,
                                        python_setup_name, NULL, python_setup};
  // vhpi_assert doesn't seem to work at this point
  assert(vhpi_register_foreignf(&python_setup_data) != NULL);

  char python_cleanup_name[] = "python_cleanup";
  vhpiForeignDataT python_cleanup_data = {
      vhpiProcF, library_name, python_cleanup_name, NULL, python_cleanup};
  assert(vhpi_register_foreignf(&python_cleanup_data) != NULL);

  char eval_integer_name[] = "eval_integer";
  vhpiForeignDataT eval_integer_data = {vhpiProcF, library_name,
                                        eval_integer_name, NULL, eval_integer};
  assert(vhpi_register_foreignf(&eval_integer_data) != NULL);

  char eval_real_name[] = "eval_real";
  vhpiForeignDataT eval_real_data = {vhpiProcF, library_name, eval_real_name,
                                     NULL, eval_real};
  assert(vhpi_register_foreignf(&eval_real_data) != NULL);

  char eval_integer_vector_name[] = "eval_integer_vector";
  vhpiForeignDataT eval_integer_vector_data = {vhpiProcF, library_name,
                                               eval_integer_vector_name, NULL,
                                               eval_integer_vector};
  assert(vhpi_register_foreignf(&eval_integer_vector_data) != NULL);

  char eval_real_vector_name[] = "eval_real_vector";
  vhpiForeignDataT eval_real_vector_data = {
      vhpiProcF, library_name, eval_real_vector_name, NULL, eval_real_vector};
  assert(vhpi_register_foreignf(&eval_real_vector_data) != NULL);

  char eval_string_name[] = "eval_string";
  vhpiForeignDataT eval_string_data = {vhpiProcF, library_name,
                                       eval_string_name, NULL, eval_string};
  assert(vhpi_register_foreignf(&eval_string_data) != NULL);

  char exec_name[] = "exec";
  vhpiForeignDataT exec_data = {vhpiProcF, library_name, exec_name, NULL, exec};
  assert(vhpi_register_foreignf(&exec_data) != NULL);
}

PLI_VOID (*vhpi_startup_routines[])() = {register_foreign_subprograms, NULL};
