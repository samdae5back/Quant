/*
 * series.h - single time-series transforms.
 *
 * All functions take an input series x of length n and write n values to out.
 * Positions that cannot be computed (the first w-1 of a rolling window, the
 * first element of a difference) are set to NaN.
 */
#ifndef QCORE_SERIES_H
#define QCORE_SERIES_H

#include <stddef.h>
#include "qcore/qcore.h"

#ifdef __cplusplus
extern "C" {
#endif

/* out[0] = NaN, out[i] = x[i] - x[i-1] */
int qc_diff(const double *x, size_t n, double *out);

/* out[0] = NaN, out[i] = x[i] / x[i-1] - 1 */
int qc_returns(const double *x, size_t n, double *out);

/* out[0] = NaN, out[i] = log(x[i] / x[i-1]) */
int qc_log_returns(const double *x, size_t n, double *out);

/* out[i] = mean(x[i-w+1 .. i]); first w-1 entries NaN. O(n). */
int qc_rolling_mean(const double *x, size_t n, size_t w, double *out);

/* out[i] = sample standard deviation (ddof = 1) over x[i-w+1 .. i]. Requires w >= 2. O(n). */
int qc_rolling_std(const double *x, size_t n, size_t w, double *out);

/* out[i] = (x[i] - rolling_mean) / rolling_std over the trailing window. Requires w >= 2. */
int qc_rolling_zscore(const double *x, size_t n, size_t w, double *out);

/* Exponentially weighted moving average. out[0] = x[0];
 * out[i] = alpha * x[i] + (1 - alpha) * out[i-1]. Requires 0 < alpha <= 1.
 * A NaN input is skipped: out[i] = out[i-1]. */
int qc_ewma(const double *x, size_t n, double alpha, double *out);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_SERIES_H */
