#include <math.h>
#include <string.h>
#include "qcore/linalg.h"

int qc_cholesky(const double *a, size_t n, double *l)
{
    if (!a || !l || n == 0) return QC_EINVAL;
    memset(l, 0, n * n * sizeof(double));
    for (size_t j = 0; j < n; j++) {
        double s = a[j * n + j];
        for (size_t k = 0; k < j; k++) s -= l[j * n + k] * l[j * n + k];
        if (!(s > 0.0)) return QC_ESINGULAR; /* also catches NaN */
        double ljj = sqrt(s);
        l[j * n + j] = ljj;
        for (size_t i = j + 1; i < n; i++) {
            double t = a[i * n + j];
            for (size_t k = 0; k < j; k++) t -= l[i * n + k] * l[j * n + k];
            l[i * n + j] = t / ljj;
        }
    }
    return QC_OK;
}

int qc_cholesky_solve(const double *l, size_t n, const double *b, double *x)
{
    if (!l || !b || !x || n == 0) return QC_EINVAL;
    /* forward: l y = b (y stored in x) */
    for (size_t i = 0; i < n; i++) {
        double s = b[i];
        for (size_t k = 0; k < i; k++) s -= l[i * n + k] * x[k];
        double d = l[i * n + i];
        if (d == 0.0) return QC_ESINGULAR;
        x[i] = s / d;
    }
    /* backward: l^T x = y */
    for (size_t ii = n; ii-- > 0;) {
        double s = x[ii];
        for (size_t k = ii + 1; k < n; k++) s -= l[k * n + ii] * x[k];
        x[ii] = s / l[ii * n + ii];
    }
    return QC_OK;
}

/* Stack-free inverse: uses the output buffer as scratch for the factor, then
 * solves one unit vector at a time into a column. Needs one extra column of
 * scratch, which we take from the last row of inv temporarily. To keep it
 * simple and allocation-free for the small n this targets, we bound n. */
#define QC_LINALG_MAX_N QC_MAX_DIM

int qc_sym_inverse(const double *a, size_t n, double *inv)
{
    if (!a || !inv || n == 0 || n > QC_LINALG_MAX_N) return QC_EINVAL;
    double l[QC_LINALG_MAX_N * QC_LINALG_MAX_N];
    double e[QC_LINALG_MAX_N], col[QC_LINALG_MAX_N];
    int rc = qc_cholesky(a, n, l);
    if (rc != QC_OK) return rc;
    for (size_t j = 0; j < n; j++) {
        for (size_t i = 0; i < n; i++) e[i] = (i == j) ? 1.0 : 0.0;
        rc = qc_cholesky_solve(l, n, e, col);
        if (rc != QC_OK) return rc;
        for (size_t i = 0; i < n; i++) inv[i * n + j] = col[i];
    }
    return QC_OK;
}

int qc_sym_eigen(const double *a, size_t n, double *evals, double *evecs, size_t max_sweeps)
{
    if (!a || !evals || n == 0 || n > QC_LINALG_MAX_N) return QC_EINVAL;
    if (max_sweeps == 0) max_sweeps = 50;

    double m[QC_LINALG_MAX_N * QC_LINALG_MAX_N];
    double v[QC_LINALG_MAX_N * QC_LINALG_MAX_N];
    memcpy(m, a, n * n * sizeof(double));
    for (size_t i = 0; i < n; i++)
        for (size_t j = 0; j < n; j++) v[i * n + j] = (i == j) ? 1.0 : 0.0;

    const double eps = 1e-12;
    int converged = 0;
    for (size_t sweep = 0; sweep < max_sweeps; sweep++) {
        double off = 0.0, diag = 0.0;
        for (size_t i = 0; i < n; i++) {
            diag += m[i * n + i] * m[i * n + i];
            for (size_t j = i + 1; j < n; j++) off += m[i * n + j] * m[i * n + j];
        }
        if (off <= eps * eps * (diag > 0.0 ? diag : 1.0)) { converged = 1; break; }

        for (size_t p = 0; p < n; p++) {
            for (size_t q = p + 1; q < n; q++) {
                double apq = m[p * n + q];
                if (fabs(apq) < 1e-300) continue;
                double app = m[p * n + p], aqq = m[q * n + q];
                double theta = (aqq - app) / (2.0 * apq);
                double t = (theta >= 0.0 ? 1.0 : -1.0) / (fabs(theta) + sqrt(theta * theta + 1.0));
                double c = 1.0 / sqrt(t * t + 1.0);
                double s = t * c;
                for (size_t k = 0; k < n; k++) {
                    double mkp = m[k * n + p], mkq = m[k * n + q];
                    m[k * n + p] = c * mkp - s * mkq;
                    m[k * n + q] = s * mkp + c * mkq;
                }
                for (size_t k = 0; k < n; k++) {
                    double mpk = m[p * n + k], mqk = m[q * n + k];
                    m[p * n + k] = c * mpk - s * mqk;
                    m[q * n + k] = s * mpk + c * mqk;
                }
                for (size_t k = 0; k < n; k++) {
                    double vkp = v[k * n + p], vkq = v[k * n + q];
                    v[k * n + p] = c * vkp - s * vkq;
                    v[k * n + q] = s * vkp + c * vkq;
                }
            }
        }
    }

    /* selection sort of eigenvalues, descending, carrying eigenvector columns */
    size_t order[QC_LINALG_MAX_N];
    for (size_t i = 0; i < n; i++) order[i] = i;
    for (size_t i = 0; i < n; i++) {
        size_t best = i;
        for (size_t j = i + 1; j < n; j++)
            if (m[order[j] * n + order[j]] > m[order[best] * n + order[best]]) best = j;
        size_t tmp = order[i]; order[i] = order[best]; order[best] = tmp;
    }
    for (size_t j = 0; j < n; j++) {
        size_t src = order[j];
        evals[j] = m[src * n + src];
        if (evecs)
            for (size_t i = 0; i < n; i++) evecs[i * n + j] = v[i * n + src];
    }
    return converged ? QC_OK : QC_ENOCONV;
}
