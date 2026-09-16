# Architecture

## Three layers

| Package | Directory | Language | Role |
|---|---|---|---|
| `quant-core` | `core/` | C11 + Haskell FFI | Numeric kernels: rolling statistics, small linear algebra, regime geometry, portfolio simulation |
| `quant` | `lib/` | Haskell | Domain: data loading and alignment, indicators, state vector, meta index, regimes, strategies, backtest, metrics |
| `quant-cli` | `cli/` | Haskell | Thin executable wiring configuration and local data to the library |

Code flows downward only: the CLI depends on `quant`, `quant` depends on
`quant-core`, and `quant-core` depends on nothing but `base` and `vector`.

## The C / Haskell boundary

* Calls cross the boundary once per series or panel, never per element.
* The C API takes `double *`, lengths and returns an integer status. No
  structs, callbacks or allocation cross the boundary.
* Haskell allocates every output buffer (`Data.Vector.Storable`), passes
  pointers with `unsafeWith`, and frees nothing that C made.
* Panels are row-major `[T][K]`. `Quant.Core.Matrix` is the only Haskell
  module that knows this; everything else uses its accessors.
* `Quant.Core.FFI` is the only module with `foreign import`. Every import is
  `unsafe` because kernels are short and never call back into Haskell.
* Kernels are checked twice: C unit tests in `core/ctest` with golden values,
  and QuickCheck properties in `lib/test/CoreVsReferenceSpec.hs` against the
  naive Haskell implementations in `lib/test/Reference/`.

## Pipeline as modules

```
Data.Fred / Data.Prices  ->  Data.Cache  ->  Data.Align (as-of by release date)
        -> Indicator (transform, sign, lag, z-window)  ->  State ([T][K] panel)
        -> MetaIndex (equal | PCA | fixed weights)      ->  Regime (turbulence, absorption, label)
        -> Strategy (weights [T][N])  ->  Backtest (schedule, C simulate)  ->  Metrics -> Report
```

Each CLI sub-command stops at one stage and writes a file, so intermediate
results can be inspected from a notebook.

## Code vs configuration vs data

* Indicator definitions and strategy logic are Haskell code, compiled into
  the binary. The type checker sees a wrong sign or transform.
* Strategy parameters (thresholds, weights, schedule, costs) are JSON under
  `config/`, read at run time. Variants are files, not modules.
* Market data lives outside git under a data directory
  (`data/cache` in development, `~/.local/share/quant` when installed).
  `data/sample` holds synthetic fixtures so the pipeline runs offline.
