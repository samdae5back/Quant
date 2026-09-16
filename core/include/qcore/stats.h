/*
 * stats.h - descriptive statistics and regression on panels.
 *
 * Panels are row-major [T][K]: T observations of K variables.
 */
#ifndef QCORE_STATS_H
#define QCORE_STATS_H

#include <stddef.h>
#include "qcore/qcore.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Arithmetic mean of x[0..n). NaN entries are skipped; all-NaN gives NaN. */
int qc_mean(const double *x, size_t n, double *out);

/* Column means of a [T][K] panel. Writes K values. NaN entries are skipped per column. */
int qc_column_means(const double *panel, size_t t, size_t k, double *out);

/* Sample covariance matrix (ddof = 1) of a [T][K] panel. Writes K*K values, row-major.
 * Rows containing any NaN are dropped. Requires at least 2 complete rows. */
int qc_covariance(const double *panel, size_t t, size_t k, double *cov);

/* Pearson correlation matrix of a [T][K] panel. Writes K*K values. */
int qc_correlation(const double *panel, size_t t, size_t k, double *corr);

/* Ordinary least squares: y ~ X (+ intercept).
 *   X      [T][K] regressors, y [T] response.
 *   beta   K values, or K+1 if intercept != 0 (intercept is written LAST).
 *   resid_var may be NULL; otherwise receives the residual variance
 *          sum(e^2) / (T_complete - p) where p is the number of coefficients.
 * Rows with any NaN in X or y are dropped. Solved via normal equations + Cholesky. */
int qc_ols(const double *X, const double *y, size_t t, size_t k, int intercept,
           double *beta, double *resid_var);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_STATS_H */
