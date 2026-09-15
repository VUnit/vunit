/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
 *
 * FLI front end of the bridge, compiled into the library only for
 * Questa/ModelSim. Every entry point of bridge.h gets an fli_ prefixed
 * foreign subprogram that converts the FLI parameters and delegates, so that
 * the bridge itself, the generated VHDL and python_ffi_pkg_bridge.vhd are the
 * same for all simulators.
 *
 * Parameter and return type mapping, from the tables of "Matching VHDL
 * Parameters with C Parameters" and "Matching VHDL Return Types with C Return
 * Types" in the Questa Foreign Language Interface Manual:
 *   - A VHDL integer IN parameter of class constant is passed by value as int.
 *   - An array parameter, IN or OUT, is passed as an mtiVariableIdT handle.
 *     mti_GetArrayVarValue(id, NULL) returns a pointer to the storage of the
 *     variable itself, which is both read and written in place. The element
 *     type decides what it points to: char for string (an enumeration with at
 *     most 256 values), mtiInt32T for integer_vector and double for
 *     real_vector, which is exactly the ABI of bridge.h.
 *   - A function returning integer returns int, one returning real returns
 *     the mtiRealT union, assigned with MTI_ASSIGN_TO_REAL.
 * Arrays are not null terminated and the handles are only valid during the
 * call, neither of which matters here: every chunk carries its length and
 * nothing is kept after the call returns.
 */

#include "bridge.h"

#include "mti.h"

/* ------------------------------------------------------------------------ */
/* Scalars only: passed by value and returned as int                         */
/* ------------------------------------------------------------------------ */

VPY_EXPORT int fli_vpy_setup(void) { return (int)vpy_setup(); }

VPY_EXPORT int fli_vpy_cleanup(void) { return (int)vpy_cleanup(); }

VPY_EXPORT int fli_vpy_buffer_clear(void) { return (int)vpy_buffer_clear(); }

VPY_EXPORT int fli_vpy_begin(void) { return (int)vpy_begin(); }

VPY_EXPORT int fli_vpy_execute(int is_file) { return (int)vpy_execute((int32_t)is_file); }

VPY_EXPORT int fli_vpy_eval(int kind, int width) { return (int)vpy_eval((int32_t)kind, (int32_t)width); }

VPY_EXPORT int fli_vpy_push_array(int length, int width, int height, int depth, int bit_width, int is_signed) {
  return (int)vpy_push_array((int32_t)length, (int32_t)width, (int32_t)height, (int32_t)depth, (int32_t)bit_width,
                             (int32_t)is_signed);
}

VPY_EXPORT int fli_vpy_stage(void) { return (int)vpy_stage(); }

VPY_EXPORT int fli_vpy_result_integer(void) { return (int)vpy_result_integer(); }

VPY_EXPORT int fli_vpy_result_meta(int index) { return (int)vpy_result_meta((int32_t)index); }

VPY_EXPORT int fli_vpy_error_length(void) { return (int)vpy_error_length(); }

/* A VHDL function returning real returns the mtiRealT union, not a double. */
VPY_EXPORT mtiRealT fli_vpy_result_real(void) {
  mtiRealT result;

  MTI_ASSIGN_TO_REAL(result, vpy_result_real());
  return result;
}

/* ------------------------------------------------------------------------ */
/* Chunks: constrained arrays passed as mtiVariableIdT                       */
/* ------------------------------------------------------------------------ */

VPY_EXPORT int fli_vpy_buffer_append(mtiVariableIdT chunk, int length) {
  return (int)vpy_buffer_append((const char *)mti_GetArrayVarValue(chunk, NULL), (int32_t)length);
}

VPY_EXPORT int fli_vpy_array_write(mtiVariableIdT chunk, int length) {
  return (int)vpy_array_write((const int32_t *)mti_GetArrayVarValue(chunk, NULL), (int32_t)length);
}

VPY_EXPORT void fli_vpy_result_read_string(mtiVariableIdT chunk, int offset, int length) {
  vpy_result_read_string((char *)mti_GetArrayVarValue(chunk, NULL), (int32_t)offset, (int32_t)length);
}

VPY_EXPORT void fli_vpy_result_read_integers(mtiVariableIdT chunk, int offset, int length) {
  vpy_result_read_integers((int32_t *)mti_GetArrayVarValue(chunk, NULL), (int32_t)offset, (int32_t)length);
}

VPY_EXPORT void fli_vpy_result_read_reals(mtiVariableIdT chunk, int offset, int length) {
  vpy_result_read_reals((double *)mti_GetArrayVarValue(chunk, NULL), (int32_t)offset, (int32_t)length);
}

VPY_EXPORT void fli_vpy_error_read(mtiVariableIdT chunk, int offset, int length) {
  vpy_error_read((char *)mti_GetArrayVarValue(chunk, NULL), (int32_t)offset, (int32_t)length);
}
