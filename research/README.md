# research/

Python side of the project: plotting and exploratory analysis only. The
Haskell binary writes CSV and JSON under `runs/`; notebooks here read those
files. No strategy logic belongs in this directory.

- `make_sample_data.py` regenerates the synthetic fixtures in `data/sample/`.
  They are random walks for exercising the pipeline offline, not market data.
