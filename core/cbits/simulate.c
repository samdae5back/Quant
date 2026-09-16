#include <math.h>
#include "qcore/simulate.h"

int qc_simulate(const double *prices, const double *weights, size_t t, size_t n,
                double cost_bps, double *equity, double *turnover)
{
    if (!prices || !weights || !equity || t == 0 || n == 0 || cost_bps < 0.0) return QC_EINVAL;

    const double cost_rate = cost_bps / 10000.0;
    double eq = 1.0;

    /* entering the initial position from cash */
    double to0 = 0.0;
    for (size_t i = 0; i < n; i++) {
        double w = weights[i];
        if (!isnan(w)) to0 += fabs(w);
    }
    eq -= eq * to0 * cost_rate;
    equity[0] = eq;
    if (turnover) turnover[0] = to0;

    for (size_t s = 0; s + 1 < t; s++) {
        const double *w_now = weights + s * n;
        const double *p_now = prices + s * n;
        const double *p_next = prices + (s + 1) * n;

        /* portfolio return from close s to close s+1 using weights decided at s */
        double port_ret = 0.0;
        for (size_t i = 0; i < n; i++) {
            double w = w_now[i];
            if (isnan(w) || w == 0.0) continue;
            double p0 = p_now[i], p1 = p_next[i];
            if (isnan(p0) || isnan(p1) || p0 == 0.0) continue; /* untradeable: flat */
            port_ret += w * (p1 / p0 - 1.0);
        }
        eq *= (1.0 + port_ret);

        /* rebalance to weights[s+1] at close s+1, pay cost on turnover */
        const double *w_next = weights + (s + 1) * n;
        double to = 0.0;
        for (size_t i = 0; i < n; i++) {
            double a = isnan(w_now[i]) ? 0.0 : w_now[i];
            double b = isnan(w_next[i]) ? 0.0 : w_next[i];
            to += fabs(b - a);
        }
        eq -= eq * to * cost_rate;

        equity[s + 1] = eq;
        if (turnover) turnover[s + 1] = to;
    }
    return QC_OK;
}
