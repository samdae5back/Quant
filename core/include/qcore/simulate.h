/*
 * simulate.h - vectorised portfolio simulation.
 *
 * The contract that separates "what to hold" (decided in Haskell) from
 * "what did that earn" (computed here).
 */
#ifndef QCORE_SIMULATE_H
#define QCORE_SIMULATE_H

#include <stddef.h>
#include "qcore/qcore.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Simulate a long-only or long-short portfolio from a target-weight panel.
 *
 *   prices    [T][N] close prices.
 *   weights   [T][N] target weights. weights[t] is decided at the close of bar t
 *             and earns the return from close t to close t+1. This one-bar shift
 *             is the look-ahead guard; do not pre-shift the weights.
 *   cost_bps  proportional transaction cost in basis points, charged on turnover.
 *   equity    T values, equity[0] = 1.0.
 *   turnover  T values, sum over assets of |weights[t] - weights[t-1]|; turnover[0]
 *             is the cost of entering the initial position from all-cash. May be NULL.
 *
 * A NaN price yields a zero return for that asset on that bar (untradeable, flat).
 * A NaN weight is treated as zero. Weights that do not sum to one leave the
 * remainder in cash earning zero. Turnover is measured target-to-target, not
 * against drifted weights; that refinement is left to a later version.
 */
int qc_simulate(const double *prices, const double *weights, size_t t, size_t n,
                double cost_bps, double *equity, double *turnover);

#ifdef __cplusplus
}
#endif

#endif /* QCORE_SIMULATE_H */
