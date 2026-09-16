/*
 * qcore.h - umbrella header for the quant-core C kernels.
 *
 * Conventions shared by every kernel in this library:
 *
 *   * Pure numeric functions: no global state, no I/O, no exit(), no malloc
 *     unless documented. Same input always yields the same output.
 *   * Caller allocates every output buffer. The library never frees or
 *     retains caller memory.
 *   * Panels (2-D data) are row-major [T][K]: element (t, k) lives at
 *     p[t * K + k]. Rows are time, columns are variables/assets.
 *   * Missing values are NaN. A window that contains a NaN produces NaN.
 *   * Every function returns a qc_status code; 0 means success.
 *   * Matrix routines (linalg, stats, regime) are allocation-free and use
 *     fixed stack buffers; they accept at most QC_MAX_DIM variables. This is
 *     ample for a macro state vector and keeps FFI calls safe on small
 *     thread stacks.
 */
#ifndef QCORE_QCORE_H
#define QCORE_QCORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define QC_VERSION_MAJOR 0
#define QC_VERSION_MINOR 1
#define QC_VERSION_PATCH 0

/* Upper bound on the number of variables in matrix routines. */
#define QC_MAX_DIM 64

typedef enum qc_status {
    QC_OK        = 0,  /* success */
    QC_EINVAL    = 1,  /* bad argument: NULL pointer, zero length, window > n, shape mismatch */
    QC_ESINGULAR = 2,  /* matrix is singular or not positive definite */
    QC_ENOCONV   = 3   /* iterative algorithm did not converge */
} qc_status;

/* Human-readable name for a status code. Never returns NULL. */
const char *qc_status_str(int status);

/* Library version as "MAJOR.MINOR.PATCH". */
const char *qc_version(void);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_QCORE_H */
