/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * The embedded interpreter. It is initialized lazily on first use, in the
 * Python environment that runs VUnit, and kept alive for the lifetime of the
 * simulator process (it is never finalized).
 */

#include "bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

typedef enum { STATE_UNINITIALIZED, STATE_READY, STATE_FAILED } state_t;

static state_t g_state = STATE_UNINITIALIZED;
static vpy_config_t g_config;
static PyObject *g_runtime = NULL; /* runtime.Runtime instance, strong reference */

PyObject *vpy_runtime(void) { return g_runtime; }

#ifdef _WIN32
/* malloc'ed wide string of a UTF-8 string, NULL on failure. */
static wchar_t *to_wide(const char *text) {
  int length = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
  wchar_t *wide;

  if (length <= 0) {
    return NULL;
  }
  wide = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)length);
  if (wide != NULL) {
    MultiByteToWideChar(CP_UTF8, 0, text, -1, wide, length);
  }
  return wide;
}
#endif

/*
 * Make the Python runtime library usable by extension modules.
 *
 * Windows: this library delay-loads pythonXY.dll. Load it by absolute path
 * before the first Python API call so the delay-load helper finds it no
 * matter how the simulator's DLL search path looks.
 *
 * POSIX: simulators dlopen() this library with RTLD_LOCAL, which makes
 * libpython (our dependency) invisible to extension modules such as NumPy
 * that expect the Python symbols to be globally available. Promote libpython
 * to RTLD_GLOBAL.
 */
static int load_python_library(void) {
#ifdef _WIN32
  wchar_t *wpath = to_wide(g_config.python_dll);
  HMODULE module;

  if (wpath == NULL) {
    vpy_set_error("Invalid Python DLL path in the Python bridge configuration");
    return VPY_ERROR;
  }
  module = LoadLibraryExW(wpath, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
  free(wpath);
  if (module == NULL) {
    unsigned long code = (unsigned long)GetLastError();
    size_t size = strlen(g_config.python_dll) + 80;
    char *message = (char *)malloc(size);

    if (message == NULL) {
      vpy_set_error("Failed to load the Python DLL");
    } else {
      snprintf(message, size, "Failed to load the Python DLL %s (Windows error %lu)", g_config.python_dll, code);
      vpy_set_error(message);
      free(message);
    }
    return VPY_ERROR;
  }
  /* Intentionally never freed: the interpreter lives until process exit. */
  return VPY_OK;
#else
  Dl_info info;

  if (dladdr((void *)&Py_InitializeFromConfig, &info) != 0 && info.dli_fname != NULL) {
    /* Intentionally never closed: the interpreter lives until process exit. */
    if (dlopen(info.dli_fname, RTLD_NOW | RTLD_GLOBAL | RTLD_NOLOAD) == NULL) {
      vpy_set_error2("Failed to make the Python library globally visible: ", dlerror());
      return VPY_ERROR;
    }
  }
  return VPY_OK;
#endif
}

static int set_config_string(PyConfig *config, wchar_t **field, const char *value) {
  PyStatus status;
#ifdef _WIN32
  wchar_t *wvalue = to_wide(value);

  if (wvalue == NULL) {
    vpy_set_error("Invalid path in the Python bridge configuration");
    return VPY_ERROR;
  }
  status = PyConfig_SetString(config, field, wvalue);
  free(wvalue);
#else
  status = PyConfig_SetBytesString(config, field, value);
#endif
  if (PyStatus_Exception(status)) {
    vpy_set_error2("Failed to configure Python: ", status.err_msg);
    return VPY_ERROR;
  }
  return VPY_OK;
}

/* Create the interpreter. On success this thread holds the GIL. */
static int initialize_interpreter(void) {
  PyConfig config;
  PyStatus status;

  PyConfig_InitPythonConfig(&config);
  /* The simulator owns the process: no signal handlers, no argv parsing. */
  config.install_signal_handlers = 0;
  config.parse_argv = 0;

  /* Make path configuration behave as if the interpreter that launched VUnit
   * was started, which selects the same installation, virtual environment
   * and site-packages. */
  if (set_config_string(&config, &config.program_name, g_config.executable) != VPY_OK ||
      set_config_string(&config, &config.executable, g_config.executable) != VPY_OK) {
    PyConfig_Clear(&config);
    return VPY_ERROR;
  }

  status = Py_InitializeFromConfig(&config);
  PyConfig_Clear(&config);
  if (PyStatus_Exception(status)) {
    vpy_set_error2("Failed to initialize Python: ", status.err_msg != NULL ? status.err_msg : "unknown error");
    return VPY_ERROR;
  }
  return VPY_OK;
}

/* Add a UTF-8 configuration string to a dict. GIL held. */
static int set_item(PyObject *dict, const char *key, const char *value) {
  PyObject *object = PyUnicode_DecodeUTF8(value, (Py_ssize_t)strlen(value), "surrogateescape");
  int status;

  if (object == NULL) {
    return -1;
  }
  status = PyDict_SetItemString(dict, key, object);
  Py_DECREF(object);
  return status;
}

/* Load ../runtime.py and create the Runtime instance. GIL held. */
static int create_runtime(void) {
  static const char *bootstrap =
      "import importlib.util, sys\n"
      "_spec = importlib.util.spec_from_file_location('_vunit_python_runtime', runtime_path)\n"
      "_module = importlib.util.module_from_spec(_spec)\n"
      "sys.modules[_spec.name] = _module\n"
      "_spec.loader.exec_module(_module)\n"
      "runtime = _module.Runtime(run_script_dir=run_script_dir, prefix=prefix)\n";
  PyObject *globals = PyDict_New();
  PyObject *ret = NULL;
  int status = VPY_ERROR;

  if (globals == NULL || PyDict_SetItemString(globals, "__builtins__", PyEval_GetBuiltins()) < 0 ||
      set_item(globals, "runtime_path", g_config.runtime) < 0 ||
      set_item(globals, "run_script_dir", g_config.run_script_dir) < 0 ||
      set_item(globals, "prefix", g_config.prefix) < 0) {
    vpy_set_error_from_python();
    goto done;
  }

  ret = PyRun_String(bootstrap, Py_file_input, globals, globals);
  if (ret == NULL) {
    vpy_set_error_from_python();
    goto done;
  }

  g_runtime = PyDict_GetItemString(globals, "runtime"); /* borrowed */
  if (g_runtime == NULL) {
    vpy_set_error("Failed to create the Python bridge runtime");
    goto done;
  }
  Py_INCREF(g_runtime);
  status = VPY_OK;

done:
  Py_XDECREF(ret);
  Py_XDECREF(globals);
  return status;
}

/*
 * Initialize on first use. Failure is sticky: the error text keeps the reason
 * and every later operation fails with it.
 */
int vpy_initialize(void) {
  int we_initialized;
  PyGILState_STATE gil = PyGILState_UNLOCKED;
  int status;

  if (g_state != STATE_UNINITIALIZED) {
    return g_state == STATE_READY ? VPY_OK : VPY_ERROR;
  }
  g_state = STATE_FAILED;

  if (vpy_read_config(&g_config) != VPY_OK || load_python_library() != VPY_OK) {
    return VPY_ERROR;
  }

  /* Reuse an interpreter embedded by someone else in this process. */
  we_initialized = !Py_IsInitialized();
  if (we_initialized) {
    if (initialize_interpreter() != VPY_OK) {
      return VPY_ERROR;
    }
  } else {
    gil = PyGILState_Ensure();
  }

  status = create_runtime();

  if (we_initialized) {
    /* Release the GIL taken by initialization. Every entry point acquires it
     * with PyGILState_Ensure, from whatever thread the simulator happens to
     * call us on. The thread state is kept forever. */
    PyEval_SaveThread();
  } else {
    PyGILState_Release(gil);
  }

  if (status == VPY_OK) {
    g_state = STATE_READY;
  }
  return status;
}

/* Whether the interpreter and the runtime are ready to be used. */
int vpy_is_initialized(void) { return g_state == STATE_READY; }

/*
 * Common start of the entry points that use Python after vpy_begin: fail if
 * the bridge is not initialized, else take the GIL.
 */
int vpy_enter(PyGILState_STATE *gil) {
  if (g_state != STATE_READY) {
    if (!vpy_has_error()) {
      vpy_set_error("Internal error: the Python bridge is not initialized");
    }
    return VPY_ERROR;
  }
  *gil = PyGILState_Ensure();
  return VPY_OK;
}

/* Status of a Python call returning ret (a new reference or NULL), which is consumed. */
int vpy_finish_call(PyObject *ret) {
  if (ret == NULL) {
    vpy_set_error_from_python();
    return VPY_ERROR;
  }
  Py_DECREF(ret);
  return VPY_OK;
}
