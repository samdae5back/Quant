# Methodology

This file fixes the definitions the code implements. Change the code and this
file together.

## State vector

For each indicator `k` with raw aligned series `x_k`:

1. Transform to a stationary series: `Level`, `Diff`, `Return` or `LogReturn`.
2. Rolling z-score over the indicator's window (default 252 daily bars):
   `z_t = (y_t - mean(y_{t-w+1..t})) / std(y_{t-w+1..t})`.
3. Multiply by the sign convention so that a positive value means risk-on.
   VIX, credit spreads, the dollar, claims and gold carry `RiskOff` and are
   negated.

The state vector `s_t` is the row of these values on date `t`.

## Alignment and look-ahead

Every observation carries a release date. On date `t` a series contributes
its latest observation whose release date is `<= t`. Sources that publish
observation dates only get a fixed lag per indicator (`indLagDays`). Weekly
claims are lagged five days. The planned ALFRED integration replaces the
fixed lag with true vintages.

## Meta index

`M_t = w . s_t`, with `w` normalised to unit absolute sum. Weighting schemes:

* `Equal`: `w_k = 1/K`. Zero free parameters.
* `PCA`: first principal component of the covariance of complete rows,
  oriented so the loading sum is positive. Zero free parameters.
* `Fixed`: an economic prior. Never fit `w` against the asset you trade.

Sanity check: correlate `M_t` with the Chicago Fed NFCI.

## Regime statistics

* Turbulence: Mahalanobis distance `sqrt((s_t - mu)^T Sigma^-1 (s_t - mu))`.
* Absorption ratio: share of variance in the top `m` eigenvalues of `Sigma`.

Both currently use full-sample `mu` and `Sigma`, which is descriptive only.
Inside a backtest they must be estimated on a trailing window; that is the
next item on the roadmap.

## Simulator contract

`weights[t]` is decided at the close of bar `t` and earns the return from
close `t` to close `t+1`. Costs are charged in basis points on turnover,
measured target-to-target. NaN prices are untradeable and earn zero.
Weights not summing to one leave the remainder in cash at zero.

## Strategy: regime tilt

Two assets, risky and safe. The meta index is classified into
risk-on / neutral / risk-off with two thresholds; each regime maps to a
risky weight; the safe asset takes the remainder. Rebalanced on the schedule
in the config (default monthly). Benchmark: buy and hold of the risky asset.
The realistic goal is a smaller maximum drawdown, not a higher return.

## Strategy: trend filter

The most basic rule-based strategy, built from three price indicators in
`Quant.Technical`:

* Trend: close above its `smaWindow`-bar simple moving average.
* Momentum: trailing `momentumWindow`-bar total return above zero.
* Volatility: annualised standard deviation of daily returns over
  `volWindow` bars.

Risky weight `w_t = min(maxWeight, targetVol / realizedVol_t)` while both
trend and momentum conditions hold, otherwise zero; the safe asset takes
`1 - w_t`. Until all three indicators are finite the strategy holds the safe
asset. Rebalanced on the configured schedule (default monthly). It exists as
a baseline the macro strategies must beat, and as the smallest complete
example of the strategy record.

## Roadmap

1. Rolling (out-of-sample) turbulence and absorption.
2. ALFRED vintages for release dates.
3. NYSE holiday calendar from a data file.
4. Macro beta vectors per stock and cosine similarity ranking
   (`Quant.Exposure`, kernels exist, no CLI yet).
5. Walk-forward evaluation.
6. Broker adapter and paper trading.
