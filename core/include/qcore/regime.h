/*
 * regime.h - geometry of the macro state vector.
 *
 * These are the "shape of the point cloud" statistics: how far today's state
 * sits from its history (turbulence) and how concentrated the variance is
 * (absorption ratio).
 */
#ifndef QCORE_REGIME_H
#define QCORE_REGIME_H

#include <stddef.h>
#include "qcore/qcore.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Mahalanobis distance sqrt((x - mu)^T cov_inv (x - mu)) for one K-vector. */
int qc_mahalanobis(const double *x, const double *mu, const double *cov_inv, size_t k, double *out);

/* Mahalanobis distance of every row of a [T][K] panel. Writes T values; a row with NaN gives NaN. */
int qc_mahalanobis_panel(const double *panel, size_t t, size_t k,
                         const double *mu, const double *cov_inv, double *out);

/* Absorption ratio: share of total variance explained by the top m eigenvalues.
 * evals must be sorted descending (as produced by qc_sym_eigen). Requires 1 <= m <= k. */
int qc_absorption_ratio(const double *evals, size_t k, size_t m, double *out);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_REGIME_H */
