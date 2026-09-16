#include <math.h>
#include "qcore/regime.h"

#define QC_REGIME_MAX_K QC_MAX_DIM

int qc_mahalanobis(const double *x, const double *mu, const double *cov_inv, size_t k, double *out)
{
    if (!x || !mu || !cov_inv || !out || k == 0 || k > QC_REGIME_MAX_K) return QC_EINVAL;
    double d[QC_REGIME_MAX_K];
    for (size_t i = 0; i < k; i++) {
        d[i] = x[i] - mu[i];
        if (isnan(d[i])) { *out = NAN; return QC_OK; }
    }
    double q = 0.0;
    for (size_t i = 0; i < k; i++) {
        double s = 0.0;
        for (size_t j = 0; j < k; j++) s += cov_inv[i * k + j] * d[j];
        q += d[i] * s;
    }
    *out = (q < 0.0) ? 0.0 : sqrt(q);
    return QC_OK;
}

int qc_mahalanobis_panel(const double *panel, size_t t, size_t k,
                         const double *mu, const double *cov_inv, double *out)
{
    if (!panel || !out || t == 0) return QC_EINVAL;
    for (size_t i = 0; i < t; i++) {
        int rc = qc_mahalanobis(panel + i * k, mu, cov_inv, k, out + i);
        if (rc != QC_OK) return rc;
    }
    return QC_OK;
}

int qc_absorption_ratio(const double *evals, size_t k, size_t m, double *out)
{
    if (!evals || !out || k == 0 || m == 0 || m > k) return QC_EINVAL;
    double top = 0.0, total = 0.0;
    for (size_t i = 0; i < k; i++) {
        double v = evals[i];
        if (isnan(v)) { *out = NAN; return QC_OK; }
        total += v;
        if (i < m) top += v;
    }
    *out = (total <= 0.0) ? NAN : top / total;
    return QC_OK;
}
