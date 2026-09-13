/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * Configuration file written by VUnit next to the bridge library. It tells
 * the bridge which Python to embed, where the runtime is and the base
 * directory of relative Python file names.
 */

#include "bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define DIRECTORY_SEPARATOR '\\'
#else
#include <dlfcn.h>
#define DIRECTORY_SEPARATOR '/'
#endif

#define CONFIG_FILE_NAME "vunit_python_bridge.cfg"

/* Return a malloc'ed UTF-8 path of the directory containing this library. */
static char *get_library_directory(void) {
  char *path;
  char *separator;
#ifdef _WIN32
  static wchar_t wpath[32768]; /* static: keep it off the simulator stack */
  HMODULE module = NULL;
  DWORD length;
  int utf8_length;

  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          (LPCWSTR)(void *)&get_library_directory, &module)) {
    return NULL;
  }
  length = GetModuleFileNameW(module, wpath, (DWORD)(sizeof(wpath) / sizeof(wpath[0])));
  if (length == 0 || length >= sizeof(wpath) / sizeof(wpath[0])) {
    return NULL;
  }
  utf8_length = WideCharToMultiByte(CP_UTF8, 0, wpath, (int)length, NULL, 0, NULL, NULL);
  if (utf8_length <= 0) {
    return NULL;
  }
  path = (char *)malloc((size_t)utf8_length + 1);
  if (path == NULL) {
    return NULL;
  }
  WideCharToMultiByte(CP_UTF8, 0, wpath, (int)length, path, utf8_length, NULL, NULL);
  path[utf8_length] = '\0';
  separator = strrchr(path, '\\');
  if (separator == NULL) {
    separator = strrchr(path, '/');
  }
#else
  Dl_info info;

  if (dladdr((void *)&get_library_directory, &info) == 0 || info.dli_fname == NULL) {
    return NULL;
  }
  path = strdup(info.dli_fname);
  if (path == NULL) {
    return NULL;
  }
  separator = strrchr(path, '/');
#endif
  if (separator == NULL) {
    free(path);
    return NULL;
  }
  *separator = '\0';
  return path;
}

static FILE *open_utf8_path(const char *path) {
#ifdef _WIN32
  int length = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0);
  wchar_t *wpath;
  FILE *file;

  if (length <= 0) {
    return NULL;
  }
  wpath = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)length);
  if (wpath == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, length);
  file = _wfopen(wpath, L"rb");
  free(wpath);
  return file;
#else
  return fopen(path, "rb");
#endif
}

/* The configuration file next to this library, opened for reading. */
static FILE *open_config_file(void) {
  char *directory = get_library_directory();
  size_t directory_length;
  char *path;
  FILE *file;

  if (directory == NULL) {
    vpy_set_error("Failed to determine the location of the Python bridge library");
    return NULL;
  }
  directory_length = strlen(directory);
  path = (char *)malloc(directory_length + 1 + sizeof(CONFIG_FILE_NAME));
  if (path == NULL) {
    free(directory);
    vpy_set_error("Out of memory");
    return NULL;
  }
  memcpy(path, directory, directory_length);
  path[directory_length] = DIRECTORY_SEPARATOR;
  memcpy(path + directory_length + 1, CONFIG_FILE_NAME, sizeof(CONFIG_FILE_NAME));
  free(directory);

  file = open_utf8_path(path);
  if (file == NULL) {
    vpy_set_error2("Failed to open the Python bridge configuration file ", path);
  }
  free(path);
  return file;
}

/* The field of config for a key, NULL for unknown keys. */
static char **config_field(vpy_config_t *config, const char *key) {
  if (strcmp(key, "executable") == 0) {
    return &config->executable;
  }
  if (strcmp(key, "prefix") == 0) {
    return &config->prefix;
  }
  if (strcmp(key, "runtime") == 0) {
    return &config->runtime;
  }
  if (strcmp(key, "base_dir") == 0) {
    return &config->base_dir;
  }
  if (strcmp(key, "python_dll") == 0) {
    return &config->python_dll;
  }
  return NULL;
}

/*
 * Read the "key=value" lines (UTF-8) of the configuration file into config,
 * whose fields must be NULL or malloc'ed. Returns VPY_ERROR with the error
 * text set on failure.
 */
int vpy_read_config(vpy_config_t *config) {
  FILE *file = open_config_file();
  char line[8192];

  if (file == NULL) {
    return VPY_ERROR;
  }

  while (fgets(line, (int)sizeof(line), file) != NULL) {
    size_t length = strlen(line);
    char *separator;
    char **field;

    while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) {
      line[--length] = '\0';
    }
    separator = strchr(line, '=');
    if (separator == NULL) {
      continue;
    }
    *separator = '\0';
    field = config_field(config, line);
    if (field != NULL) {
      free(*field);
      *field = strdup(separator + 1);
    }
  }
  fclose(file);

  if (config->executable == NULL || config->prefix == NULL || config->runtime == NULL || config->base_dir == NULL) {
    vpy_set_error("Incomplete Python bridge configuration file");
    return VPY_ERROR;
  }
#ifdef _WIN32
  if (config->python_dll == NULL) {
    vpy_set_error("The Python bridge configuration file lacks the Python DLL path");
    return VPY_ERROR;
  }
#endif
  return VPY_OK;
}
