#include <vhpi_user.h>
#include <string>
#include <cassert>

#define PY_SSIZE_T_CLEAN
#include "Python.h"

#define MAX_VHDL_PARAMETER_STRING_LENGTH 100000

static PyObject* globals;
static PyObject* locals;

using namespace std;

PLI_VOID python_cleanup(const struct vhpiCbDataS* cb_p);

static char* get_string(PyObject *pyobj) {
  PyObject* str = PyObject_Str(pyobj);
  if (str == nullptr) {
    return nullptr;
  }

  PyObject* str_utf_8 = PyUnicode_AsEncodedString(str, "utf-8", NULL);
  Py_DECREF(str);
  if (str_utf_8 == nullptr) {
    return nullptr;
  }

  char* result = PyBytes_AS_STRING(str_utf_8);
  Py_DECREF(str_utf_8);

  return result;
}
static void py_error_handler(const char *context, const char *code_or_expr = nullptr, const char *reason = nullptr, bool cleanup = true) {
    const char* unknown_error = "Unknown error";

    // Use provided error reason or try extracting the reason from the Python exception
    if (reason == nullptr) {
      PyObject *exc;

      exc = PyErr_GetRaisedException();
      if (exc != nullptr) {
        reason = get_string(exc);
        Py_DECREF(exc);
      }
    }

    // Clean-up Python session first in case vhpi_assert stops the simulation
    if (cleanup) {
      python_cleanup(nullptr);
    }

    // Output error message
    reason = reason == nullptr ? unknown_error : reason;
    if (code_or_expr == nullptr) {
      vhpi_assert(vhpiError, "ERROR %s:\n\n%s\n\n", context, reason);
    } else {
      vhpi_assert(vhpiError, "ERROR %s:\n\n%s\n\n%s\n\n", context, code_or_expr, reason);
    }

    // Stop the simulation if vhpi_assert didn't.
    vhpi_control(vhpiStop);
}

static void vhpi_error_handler(const char* context, bool cleanup = true) {
  vhpiErrorInfoT err;

  // Clean-up Python session first in case vhpi_assert stops the simulation
  if (cleanup) {
    python_cleanup(nullptr);
  }

  if (vhpi_check_error(&err)) {
    vhpi_assert(err.severity, "ERROR %s: \n\n%s (%d): %s\n\n", context, err.file, err.line, err.message);

  } else {
    vhpi_assert(vhpiError, "ERROR %s\n\n", context);
  }

  // Stop the simulation if vhpi_assert didn't.
  vhpi_control(vhpiStop);
}

PLI_VOID python_setup(const struct vhpiCbDataS* cb_p) {
  Py_Initialize();
  if (!Py_IsInitialized()) {
    vhpi_error_handler("Failed to initialize Python", false);
  }

  PyObject* main_module = PyImport_AddModule("__main__");
  if (main_module == nullptr) {
      vhpi_error_handler("Failed to get the main module");
  }

  globals = PyModule_GetDict(main_module);
  if (globals == nullptr) {
      vhpi_error_handler("Failed to get the global dictionary");
  }

  // globals and locals are the same at the top-level
  locals = globals;
}

PLI_VOID python_cleanup(const struct vhpiCbDataS* cb_p) {
  if (locals != nullptr) {
      Py_DECREF(locals);
  }

  if (Py_FinalizeEx()) {
      vhpi_assert(vhpiWarning, "WARNING: Failed to finalize Python");
  }
}

static const char* get_parameter(const struct vhpiCbDataS* cb_p) {
  // Get parameter from VHDL function call
  vhpiHandleT parameter_handle = vhpi_handle_by_index(vhpiParamDecls, cb_p->obj, 0);
  if (parameter_handle == nullptr) {
    vhpi_error_handler("getting VHDL parameter handle");
  }

  vhpiValueT parameter;
  static char vhdl_parameter_string[MAX_VHDL_PARAMETER_STRING_LENGTH];

  parameter.bufSize = MAX_VHDL_PARAMETER_STRING_LENGTH;
  parameter.value.str = vhdl_parameter_string;
  parameter.format = vhpiStrVal;

  if (vhpi_get_value(parameter_handle, &parameter)) {
    vhpi_error_handler("getting VHDL parameter value");
  }

  return vhdl_parameter_string;
}

static PyObject* eval(const char *expr) {
  PyObject* pyobj = PyRun_String(expr, Py_eval_input, globals, locals);
  if (pyobj == nullptr) {
    py_error_handler("evaluating", expr);
  }

  return pyobj;
}

static void handle_type_check_error(PyObject* pyobj, const char *context, const char *expr) {
  PyObject* type_name = PyType_GetName(Py_TYPE(pyobj));
  if (type_name == nullptr) {
    py_error_handler(context, expr, "Expression evaluates to an unknown type.");
  }

  const char* type_name_str = get_string(type_name);
  Py_DECREF(type_name);
  if (type_name_str == nullptr) {
    py_error_handler(context, expr, "Expression evaluates to an unknown type.");
  }

  string error_message = "Expression evaluates to " + string(type_name_str);
  py_error_handler(context, expr, error_message.c_str());
}

static void check_conversion_error(const char *expr) {
  PyObject* exc = PyErr_Occurred();
  if (exc != nullptr) {
    Py_DECREF(exc);
    py_error_handler("parsing evaluation result of", expr);
  }
}

static int get_integer(PyObject* pyobj, const char* expr, bool dec_ref_count = true) {
  // Check that the Python object has the correct type
  if (!PyLong_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to integer", expr);
  }

  // Convert from Python-typed to C-typed value and check for any errors such as overflow/underflow
  long value = PyLong_AsLong(pyobj);
  if (dec_ref_count) {
    Py_DECREF(pyobj);
  }
  check_conversion_error(expr);

  // TODO: Assume that the simulator is limited to 32-bits for now
  if ((value > pow(2, 31) - 1) or (value < -pow(2, 31))) {
    py_error_handler("parsing evaluation result of", expr, "Result out of VHDL integer range.");
  }

  return int(value);
}

static double get_real(PyObject* pyobj, const char* expr, bool dec_ref_count = true) {
  // Check that the Python object has the correct type
  if (!PyFloat_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to real", expr);
  }

  // Convert from Python-typed to C-typed value and check for any errors such as overflow/underflow
  double value = PyFloat_AsDouble(pyobj);
  if (dec_ref_count) {
    Py_DECREF(pyobj);
  }
  check_conversion_error(expr);

  // TODO: Assume that the simulator is limited to 32-bits for now
  if ((value > 3.4028234664e38) or (value < -3.4028234664e38)) {
    py_error_handler("parsing evaluation result of", expr, "Result out of VHDL real range.");
  }

  return value;
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
  vhdl_result.value.intg = get_integer(eval_result, expr);
  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr);
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
  vhdl_result.value.real = get_real(eval_result, expr);
  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr);
  }
}

PLI_VOID eval_integer_vector(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* pyobj = eval(expr);

  // Check that the eval results in a list. TODO: tuple and sets of integers should also work
  if (!PyList_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to integer_vector", expr);
  }

  const int list_size = PyList_GET_SIZE(pyobj);
  const int n_bytes = list_size * sizeof(int);
  int *int_array = (int *)malloc(n_bytes);

  for (int idx = 0; idx < list_size; idx++) {
    int_array[idx] = get_integer(PyList_GetItem(pyobj, idx), expr, false);
  }
  Py_DECREF(pyobj);

  // Return result to VHDL
  vhpiValueT vhdl_result;
  vhdl_result.format = vhpiIntVecVal;
  vhdl_result.bufSize = n_bytes;
  vhdl_result.numElems = list_size;
  vhdl_result.value.intgs = (vhpiIntT *)int_array;

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiSizeConstraint)) {
    free(int_array);
    py_error_handler("setting size constraints when returning result for evaluation of", expr);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    free(int_array);
    py_error_handler("returning result for evaluation of", expr);
  }

  free(int_array);
}

PLI_VOID eval_real_vector(const struct vhpiCbDataS* cb_p) {
  // Get expression parameter from VHDL function call
  const char* expr = get_parameter(cb_p);

  // Eval(uate) expression in Python
  PyObject* pyobj = eval(expr);

  // Check that the eval results in a list. TODO: tuple and sets of integers should also work
  if (!PyList_Check(pyobj)) {
    handle_type_check_error(pyobj, "evaluating to real_vector", expr);
  }

  const int list_size = PyList_GET_SIZE(pyobj);
  const int n_bytes = list_size * sizeof(double);
  double *double_array = (double *)malloc(n_bytes);

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
    py_error_handler("setting size constraints when returning result for evaluation of", expr);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    free(double_array);
    py_error_handler("returning result for evaluation of", expr);
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
  vhdl_result.bufSize = strlen(str) + 1; //null termination included
  vhdl_result.numElems = strlen(str);
  vhdl_result.value.str = str;

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiSizeConstraint)) {
    py_error_handler("setting size constraints when returning result for evaluation of", expr);
  }

  if (vhpi_put_value(cb_p->obj, &vhdl_result, vhpiDeposit)) {
    py_error_handler("returning result for evaluation of", expr);
  }
}


PLI_VOID exec(const struct vhpiCbDataS* cb_p) {
  // Get code parameter from VHDL procedure call
  const char* code = get_parameter(cb_p);

  // Exec(ute) Python code
  if (PyRun_String(code, Py_file_input, globals, locals) == nullptr) {
    py_error_handler("executing", code);
  }
}

PLI_VOID register_foreign_subprograms() {
  char library_name[] = "python";

  char python_setup_name[] = "python_setup";
  vhpiForeignDataT python_setup_data = {vhpiProcF, library_name, python_setup_name, nullptr, python_setup};
  // vhpi_assert doesn't seem to work at this point
  assert(vhpi_register_foreignf(&python_setup_data) != nullptr);

  char python_cleanup_name[] = "python_cleanup";
  vhpiForeignDataT python_cleanup_data = {vhpiProcF, library_name, python_cleanup_name, nullptr, python_cleanup};
  assert(vhpi_register_foreignf(&python_cleanup_data) != nullptr);

  char eval_integer_name[] = "eval_integer";
  vhpiForeignDataT eval_integer_data = {vhpiProcF, library_name, eval_integer_name, nullptr, eval_integer};
  assert(vhpi_register_foreignf(&eval_integer_data) != nullptr);

  char eval_real_name[] = "eval_real";
  vhpiForeignDataT eval_real_data = {vhpiProcF, library_name, eval_real_name, nullptr, eval_real};
  assert(vhpi_register_foreignf(&eval_real_data) != nullptr);

  char eval_integer_vector_name[] = "eval_integer_vector";
  vhpiForeignDataT eval_integer_vector_data = {vhpiProcF, library_name, eval_integer_vector_name, nullptr, eval_integer_vector};
  assert(vhpi_register_foreignf(&eval_integer_vector_data) != nullptr);

  char eval_real_vector_name[] = "eval_real_vector";
  vhpiForeignDataT eval_real_vector_data = {vhpiProcF, library_name, eval_real_vector_name, nullptr, eval_real_vector};
  assert(vhpi_register_foreignf(&eval_real_vector_data) != nullptr);

  char eval_string_name[] = "eval_string";
  vhpiForeignDataT eval_string_data = {vhpiProcF, library_name, eval_string_name, nullptr, eval_string};
  assert(vhpi_register_foreignf(&eval_string_data) != nullptr);

  char exec_name[] = "exec";
  vhpiForeignDataT exec_data = {vhpiProcF, library_name, exec_name, nullptr, exec};
  assert(vhpi_register_foreignf(&exec_data) != nullptr);
}

PLI_VOID (*vhpi_startup_routines[])() = {register_foreign_subprograms, nullptr};
