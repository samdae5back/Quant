#include <math.h>
#include <string.h>
#include "qcore/stats.h"
#include "qcore/linalg.h"

#define QC_STATS_MAX_K QC_MAX_DIM

int qc_mean(const double *x, size_t n, double *out)
{
    if (!x || !out || n == 0) return QC_EINVAL;
    double s = 0.0; size_t c = 0;
    for (size_t i = 0; i < n; i++) if (!isnan(x[i])) { s += x[i]; c++; }
    *out = c ? s / (double)c : NAN;
    return QC_OK;
}

int qc_column_means(const double *panel, size_t t, size_t k, double *out)
{
    if (!panel || !out || t == 0 || k == 0) return QC_EINVAL;
    for (size_t j = 0; j < k; j++) {
        double s = 0.0; size_t c = 0;
        for (size_t i = 0; i < t; i++) {
            double v = panel[i * k + j];
            if (!isnan(v)) { s += v; c++; }
        }
        out[j] = c ? s / (double)c : NAN;
    }
    return QC_OK;
}

static int row_complete(const double *row, size_t k)
{
    for (size_t j = 0; j < k; j++) if (isnan(row[j])) return 0;
    return 1;
}

int qc_covariance(const double *panel, size_t t, size_t k, double *cov)
{
    if (!panel || !cov || t < 2 || k == 0 || k > QC_STATS_MAX_K) return QC_EINVAL;
    double mu[QC_STATS_MAX_K];
    memset(mu, 0, k * sizeof(double));
    size_t c = 0;
    for (size_t i = 0; i < t; i++) {
        const double *row = panel + i * k;
        if (!row_complete(row, k)) continue;
        c++;
        for (size_t j = 0; j < k; j++) mu[j] += row[j];
    }
    if (c < 2) return QC_EINVAL;
    for (size_t j = 0; j < k; j++) mu[j] /= (double)c;

    memset(cov, 0, k * k * sizeof(double));
    for (size_t i = 0; i < t; i++) {
        const double *row = panel + i * k;
        if (!row_complete(row, k)) continue;
        for (size_t a = 0; a < k; a++) {
            double da = row[a] - mu[a];
            for (size_t b = a; b < k; b++) cov[a * k + b] += da * (row[b] - mu[b]);
        }
    }
    double denom = (double)(c - 1);
    for (size_t a = 0; a < k; a++)
        for (size_t b = a; b < k; b++) {
            cov[a * k + b] /= denom;
            cov[b * k + a] = cov[a * k + b];
        }
    return QC_OK;
}

int qc_correlation(const double *panel, size_t t, size_t k, double *corr)
{
    int rc = qc_covariance(panel, t, k, corr);
    if (rc != QC_OK) return rc;
    double sd[QC_STATS_MAX_K];
    for (size_t a = 0; a < k; a++) sd[a] = sqrt(corr[a * k + a]);
    for (size_t a = 0; a < k; a++)
        for (size_t b = 0; b < k; b++) {
            double d = sd[a] * sd[b];
            corr[a * k + b] = (d == 0.0) ? NAN : corr[a * k + b] / d;
        }
    return QC_OK;
}

int qc_ols(const double *X, const double *y, size_t t, size_t k, int intercept,
           double *beta, double *resid_var)
{
    if (!X || !y || !beta || t == 0 || k == 0) return QC_EINVAL;
    size_t p = k + (intercept ? 1 : 0);
    if (p > QC_STATS_MAX_K || t < p) return QC_EINVAL;

    double xtx[QC_STATS_MAX_K * QC_STATS_MAX_K];
    double xty[QC_STATS_MAX_K];
    double l[QC_STATS_MAX_K * QC_STATS_MAX_K];
    double row[QC_STATS_MAX_K];
    memset(xtx, 0, p * p * sizeof(double));
    memset(xty, 0, p * sizeof(double));

    size_t used = 0;
    for (size_t i = 0; i < t; i++) {
        const double *xi = X + i * k;
        if (isnan(y[i]) || !row_complete(xi, k)) continue;
        used++;
        for (size_t j = 0; j < k; j++) row[j] = xi[j];
        if (intercept) row[k] = 1.0;
        for (size_t a = 0; a < p; a++) {
            xty[a] += row[a] * y[i];
            for (size_t b = a; b < p; b++) xtx[a * p + b] += row[a] * row[b];
        }
    }
    if (used < p) return QC_EINVAL;
    for (size_t a = 0; a < p; a++)
        for (size_t b = a + 1; b < p; b++) xtx[b * p + a] = xtx[a * p + b];

    int rc = qc_cholesky(xtx, p, l);
    if (rc != QC_OK) return rc;
    rc = qc_cholesky_solve(l, p, xty, beta);
    if (rc != QC_OK) return rc;

    if (resid_var) {
        double ss = 0.0;
        for (size_t i = 0; i < t; i++) {
            const double *xi = X + i * k;
            if (isnan(y[i]) || !row_complete(xi, k)) continue;
            double yhat = intercept ? beta[k] : 0.0;
            for (size_t j = 0; j < k; j++) yhat += beta[j] * xi[j];
            double e = y[i] - yhat;
            ss += e * e;
        }
        *resid_var = (used > p) ? ss / (double)(used - p) : NAN;
    }
    return QC_OK;
}
