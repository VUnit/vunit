// This package provides a dictionary types and operations
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

#include <stdbool.h>
#include <stdio.h>

#define PY_SSIZE_T_CLEAN
#include "Python.h"

extern PyObject* globals;
extern PyObject* locals;

typedef void (*py_error_handler_callback)(const char*, const char*, const char*,
                                          bool);
void register_py_error_handler(py_error_handler_callback callback);

typedef void (*fli_error_handler_callback)(const char*, bool);
void register_fli_error_handler(fli_error_handler_callback callback);

char* get_string(PyObject* pyobj);
void check_conversion_error(const char* expr);
void handle_type_check_error(PyObject* pyobj, const char* context,
                             const char* expr);
PyObject* eval(const char* expr);
int get_integer(PyObject* pyobj, const char* expr, bool dec_ref_count);
double get_real(PyObject* pyobj, const char* expr, bool dec_ref_count);
