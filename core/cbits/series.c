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
 * Rolling first and second moments in O(n) amortised time.
 *
 * The naive running-sum formula var = (sum(x^2) - n*mean^2) / (n-1) suffers
 * catastrophic cancellation whenever the window's values are large compared
 * to their spread (a pair like -998.7 and -999.2 loses eight digits). Instead
 * the window mean and the sum of squared deviations M2 are carried directly
 * and updated with the exact sliding identity
 *
 *     mean' = mean + (x_new - x_old) / w
 *     M2'   = M2 + (x_new - x_old) * (x_new - mean' + x_old - mean)
 *
 * The rounding error of that update is proportional to the largest M2 seen
 * since the state was last built, so when M2 shrinks by more than
 * QC_REBUILD_RATIO relative to that peak (a calm window after a volatile
 * one) the state is rebuilt with a direct two-pass over the window. The same
 * rebuild happens at the first complete window, after every NaN gap, and
 * every QC_REBUILD_EVERY steps to bound slow drift. Rebuilds cost O(w) and
 * are rare on financial data, so the amortised cost stays O(n).
 *
 * mode: 0 = mean, 1 = sample std (ddof 1), 2 = z-score of the last element.
 */
#define QC_REBUILD_RATIO 1e-2
#define QC_REBUILD_EVERY 4096

static void window_moments(const double *win, size_t w, double *mean, double *m2)
{
    double s = 0.0;
    for (size_t k = 0; k < w; k++) s += win[k];
    double mu = s / (double)w, acc = 0.0;
    for (size_t k = 0; k < w; k++) { double d = win[k] - mu; acc += d * d; }
    *mean = mu;
    *m2 = acc;
}

static int rolling_core(const double *x, size_t n, size_t w, int mode, double *out)
{
    if (!x || !out || n == 0 || w == 0 || w > n) return QC_EINVAL;
    if (mode != 0 && w < 2) return QC_EINVAL;

    size_t nan_in_window = 0;
    int valid = 0;              /* running mean/m2 describe the current window */
    size_t since_rebuild = 0;
    double mean = 0.0, m2 = 0.0, m2_peak = 0.0;

    for (size_t i = 0; i < n; i++) {
        if (isnan(x[i])) nan_in_window++;
        if (i >= w && isnan(x[i - w])) nan_in_window--;

        if (i + 1 < w || nan_in_window > 0) {
            out[i] = NAN;
            valid = 0;
            continue;
        }

        if (valid) {
            double x_new = x[i], x_old = x[i - w];
            double mean_new = mean + (x_new - x_old) / (double)w;
            double m2_new = m2 + (x_new - x_old) * (x_new - mean_new + x_old - mean);
            since_rebuild++;
            if (m2_new < QC_REBUILD_RATIO * m2_peak || since_rebuild >= QC_REBUILD_EVERY) {
                valid = 0;      /* accumulated error may dominate: rebuild below */
            } else {
                mean = mean_new;
                m2 = m2_new;
                if (m2 > m2_peak) m2_peak = m2;
            }
        }
        if (!valid) {
            window_moments(x + (i + 1 - w), w, &mean, &m2);
            m2_peak = m2;
            since_rebuild = 0;
            valid = 1;
        }
        if (m2 < 0.0) m2 = 0.0; /* rounding noise */

        if (mode == 0) {
            out[i] = mean;
        } else {
            double sd = sqrt(m2 / (double)(w - 1));
            if (mode == 1) out[i] = sd;
            else out[i] = (sd == 0.0) ? NAN : (x[i] - mean) / sd;
        }
    }
    return QC_OK;
}

int qc_rolling_mean(const double *x, size_t n, size_t w, double *out)
{
    return rolling_core(x, n, w, 0, out);
}

int qc_rolling_std(const double *x, size_t n, size_t w, double *out)
{
    return rolling_core(x, n, w, 1, out);
}

int qc_rolling_zscore(const double *x, size_t n, size_t w, double *out)
{
    return rolling_core(x, n, w, 2, out);
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
