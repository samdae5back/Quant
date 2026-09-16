#include <math.h>
#include "qcore/series.h"

int qc_diff(const double *x, size_t n, double *out)
{
    if (!x || !out || n == 0) return QC_EINVAL;
    out[0] = NAN;
    for (size_t i = 1; i < n; i++) out[i] = x[i] - x[i - 1];
    return QC_OK;
}

int qc_returns(const double *x, size_t n, double *out)
{
    if (!x || !out || n == 0) return QC_EINVAL;
    out[0] = NAN;
    for (size_t i = 1; i < n; i++) {
        double prev = x[i - 1];
        out[i] = (prev == 0.0) ? NAN : x[i] / prev - 1.0;
    }
    return QC_OK;
}

int qc_log_returns(const double *x, size_t n, double *out)
{
    if (!x || !out || n == 0) return QC_EINVAL;
    out[0] = NAN;
    for (size_t i = 1; i < n; i++) {
        double prev = x[i - 1];
        out[i] = (prev <= 0.0 || x[i] <= 0.0) ? NAN : log(x[i] / prev);
    }
    return QC_OK;
}

/*
 * Rolling first and second moments in O(n) with running sums.
 *
 * To limit cancellation error the sums are taken on (x - shift) where shift is
 * the first finite value seen; the shift cancels in the variance and is added
 * back to the mean. A count of NaNs currently inside the window is kept so
 * that windows containing missing data emit NaN without corrupting the sums.
 */
static int rolling_moments(const double *x, size_t n, size_t w,
                           double *mean_out, double *std_out)
{
    if (!x || n == 0 || w == 0 || w > n) return QC_EINVAL;
    if (std_out && w < 2) return QC_EINVAL;

    double shift = 0.0;
    int have_shift = 0;
    double sum = 0.0, sumsq = 0.0;
    size_t nan_in_window = 0;

    for (size_t i = 0; i < n; i++) {
        double xi = x[i];
        if (isnan(xi)) {
            nan_in_window++;
        } else {
            if (!have_shift) { shift = xi; have_shift = 1; }
            double d = xi - shift;
            sum += d;
            sumsq += d * d;
        }

        if (i >= w) {
            double xo = x[i - w];
            if (isnan(xo)) {
                nan_in_window--;
            } else {
                double d = xo - shift;
                sum -= d;
                sumsq -= d * d;
            }
        }

        if (i + 1 < w || nan_in_window > 0) {
            if (mean_out) mean_out[i] = NAN;
            if (std_out) std_out[i] = NAN;
            continue;
        }

        double mean_d = sum / (double)w;
        if (mean_out) mean_out[i] = mean_d + shift;
        if (std_out) {
            double var = (sumsq - (double)w * mean_d * mean_d) / (double)(w - 1);
            if (var < 0.0) var = 0.0; /* rounding noise */
            std_out[i] = sqrt(var);
        }
    }
    return QC_OK;
}

int qc_rolling_mean(const double *x, size_t n, size_t w, double *out)
{
    if (!out) return QC_EINVAL;
    return rolling_moments(x, n, w, out, NULL);
}

int qc_rolling_std(const double *x, size_t n, size_t w, double *out)
{
    if (!out) return QC_EINVAL;
    return rolling_moments(x, n, w, NULL, out);
}

int qc_rolling_zscore(const double *x, size_t n, size_t w, double *out)
{
    if (!x || !out || n == 0 || w < 2 || w > n) return QC_EINVAL;

    /* Reuse the output buffer for the mean, then rewrite in place; the std is
     * recomputed through a second pass to avoid a heap allocation. */
    int rc = rolling_moments(x, n, w, out, NULL);
    if (rc != QC_OK) return rc;

    /* Second pass: rolling std, streamed so out[i] can be finalised immediately. */
    double shift = 0.0;
    int have_shift = 0;
    double sum = 0.0, sumsq = 0.0;
    size_t nan_in_window = 0;
    for (size_t i = 0; i < n; i++) {
        double xi = x[i];
        if (isnan(xi)) nan_in_window++;
        else {
            if (!have_shift) { shift = xi; have_shift = 1; }
            double d = xi - shift; sum += d; sumsq += d * d;
        }
        if (i >= w) {
            double xo = x[i - w];
            if (isnan(xo)) nan_in_window--;
            else { double d = xo - shift; sum -= d; sumsq -= d * d; }
        }
        if (i + 1 < w || nan_in_window > 0) { out[i] = NAN; continue; }
        double mean_d = sum / (double)w;
        double var = (sumsq - (double)w * mean_d * mean_d) / (double)(w - 1);
        if (var < 0.0) var = 0.0;
        double sd = sqrt(var);
        out[i] = (sd == 0.0) ? NAN : (xi - out[i]) / sd;
    }
    return QC_OK;
}

int qc_ewma(const double *x, size_t n, double alpha, double *out)
{
    if (!x || !out || n == 0 || !(alpha > 0.0) || alpha > 1.0) return QC_EINVAL;
    double prev = NAN;
    for (size_t i = 0; i < n; i++) {
        double xi = x[i];
        if (isnan(xi)) {
            out[i] = prev;
        } else if (isnan(prev)) {
            prev = xi;
            out[i] = prev;
        } else {
            prev = alpha * xi + (1.0 - alpha) * prev;
            out[i] = prev;
        }
    }
    return QC_OK;
}
