/*
 * linalg.h - small dense linear algebra for symmetric matrices.
 *
 * Matrices are row-major [N][N]. These routines target the small dimensions
 * of a macro state vector (tens of variables), not large systems.
 */
#ifndef QCORE_LINALG_H
#define QCORE_LINALG_H

#include <stddef.h>
#include "qcore/qcore.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Cholesky factorisation a = l * l^T. l is lower triangular; the upper part is zeroed.
 * Returns QC_ESINGULAR if a is not (numerically) positive definite. */
int qc_cholesky(const double *a, size_t n, double *l);

/* Solve (l * l^T) x = b given the Cholesky factor l. */
int qc_cholesky_solve(const double *l, size_t n, const double *b, double *x);

/* Inverse of a symmetric positive definite matrix via Cholesky. Writes N*N values. */
int qc_sym_inverse(const double *a, size_t n, double *inv);

/* Eigen-decomposition of a symmetric matrix by cyclic Jacobi rotations.
 *   evals  N eigenvalues in descending order.
 *   evecs  [N][N] matrix whose COLUMN j is the eigenvector for evals[j]. May be NULL.
 *   max_sweeps  upper bound on Jacobi sweeps; 0 selects a default (50).
 * Returns QC_ENOCONV if off-diagonal mass is not negligible after max_sweeps. */
int qc_sym_eigen(const double *a, size_t n, double *evals, double *evecs, size_t max_sweeps);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_LINALG_H */
