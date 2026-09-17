# Task runner. cabal is the build system; this file only names the commands
# people type most and delegates the C-only build to core/Makefile.

.PHONY: build test ctest asan bench fetch state backtest install clean sample-data

build:
	cabal build all

test: ctest
	cabal test all

ctest:
	$(MAKE) -C core test

asan:
	$(MAKE) -C core asan

fetch:
	cabal run exe:quant -- fetch --data data/cache

state:
	cabal run exe:quant -- state --data data/cache --out runs/state.csv

backtest:
	cabal run exe:quant -- backtest --data data/cache --strategy regime-tilt \
	    --config config/strategies/regime-tilt.json

# Offline smoke run on the synthetic fixtures.
smoke:
	cabal run exe:quant -- backtest --data data/sample --strategy buy-hold --symbols SPY --out runs/smoke/buy-hold
	cabal run exe:quant -- backtest --data data/sample --strategy regime-tilt \
	    --config config/strategies/regime-tilt.json --out runs/smoke/regime-tilt
	cabal run exe:quant -- backtest --data data/sample --strategy trend-filter \
	    --config config/strategies/trend-filter.json --out runs/smoke/trend-filter

install:
	cabal install exe:quant --overwrite-policy=always

sample-data:
	python3 research/make_sample_data.py

clean:
	cabal clean
	$(MAKE) -C core clean
