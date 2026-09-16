#!/usr/bin/env python3
"""Generate SYNTHETIC sample data in the cache layout the CLI expects.

The output is random-walk noise with plausible levels, seeded for
reproducibility. It exists so the pipeline can be exercised offline and in
CI. It carries no information about real markets; never draw conclusions
from a backtest on it. Real data comes from `quant fetch`.
"""
import math
import os
import random
from datetime import date, timedelta

ROOT = os.path.join(os.path.dirname(__file__), "..", "data", "sample")
START, END = date(2018, 1, 1), date(2024, 12, 31)
rng = random.Random(20240916)


def weekdays():
    d = START
    while d <= END:
        if d.weekday() < 5:
            yield d
        d += timedelta(days=1)


DAYS = list(weekdays())


def gbm(level, mu, sigma):
    out, x = [], level
    for _ in DAYS:
        x *= math.exp(mu / 252 + sigma / math.sqrt(252) * rng.gauss(0, 1))
        out.append(x)
    return out


def ou(level, mean, speed, sigma, floor=None):
    out, x = [], level
    for _ in DAYS:
        x += speed * (mean - x) + sigma * rng.gauss(0, 1)
        if floor is not None:
            x = max(x, floor)
        out.append(x)
    return out


def fred(series_id, values, missing_every=0):
    path = os.path.join(ROOT, "fred", f"{series_id}.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("DATE,VALUE\n")
        for i, (d, v) in enumerate(zip(DAYS, values)):
            cell = "." if missing_every and i % missing_every == 7 else f"{v:.4f}"
            f.write(f"{d.isoformat()},{cell}\n")


def fred_weekly(series_id, values):
    path = os.path.join(ROOT, "fred", f"{series_id}.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("DATE,VALUE\n")
        for d, v in zip(DAYS, values):
            if d.weekday() == 5 - 1:  # Fridays stand in for the weekly reference date
                f.write(f"{d.isoformat()},{v:.0f}\n")


def price(symbol, closes):
    path = os.path.join(ROOT, "prices", f"{symbol}.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("Date,Open,High,Low,Close,Volume\n")
        for d, c in zip(DAYS, closes):
            o = c * (1 + rng.gauss(0, 0.002))
            hi, lo = max(o, c) * (1 + abs(rng.gauss(0, 0.003))), min(o, c) * (1 - abs(rng.gauss(0, 0.003)))
            f.write(f"{d.isoformat()},{o:.2f},{hi:.2f},{lo:.2f},{c:.2f},{rng.randint(1_000_000, 90_000_000)}\n")


spx = gbm(2700, 0.08, 0.18)
fred("SP500", spx, missing_every=97)
fred("VIXCLS", ou(15, 18, 0.05, 1.2, floor=9))
fred("DGS10", ou(2.4, 2.8, 0.01, 0.04, floor=0.3), missing_every=61)
fred("T10Y2Y", ou(0.5, 0.6, 0.01, 0.03))
fred("BAMLH0A0HYM2", ou(3.6, 4.2, 0.02, 0.06, floor=2.5))
fred("T10YIE", ou(2.0, 2.2, 0.02, 0.03, floor=0.5))
fred("DTWEXBGS", gbm(115, 0.01, 0.06))
fred("DCOILWTICO", gbm(60, 0.02, 0.35))
fred_weekly("ICSA", ou(220_000, 230_000, 0.05, 8_000, floor=150_000))

price("GLD", gbm(125, 0.06, 0.14))
price("SPY", [x / 10 for x in spx])                 # SPY tracks the synthetic index
price("BIL", [91.5 * (1 + 0.02 * i / 252) for i in range(len(DAYS))])  # cash-like drift
print("wrote synthetic sample data under", os.path.abspath(ROOT))
