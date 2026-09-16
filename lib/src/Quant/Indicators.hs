{-# LANGUAGE OverloadedStrings #-}
-- | The default indicator set for the US macro state vector.
--
-- Series ids are FRED identifiers. Daily series use a one-day lag (published
-- the next morning); the weekly claims series is released on Thursdays for
-- the prior week and gets a longer lag. Gold uses an ETF price because the
-- LBMA series on FRED was discontinued. Verify ids against FRED before
-- relying on them; a renamed series silently becomes all-NaN.
module Quant.Indicators
  ( defaultIndicators
  , priceSymbolsNeeded
  , fredSeriesNeeded
  ) where

import Quant.Indicator
import Quant.Types

daily :: Window
daily = Window 252

defaultIndicators :: [Indicator]
defaultIndicators =
  [ Indicator "spx"      (Fred (SeriesId "SP500"))          LogReturn RiskOn  1 daily
  , Indicator "vix"      (Fred (SeriesId "VIXCLS"))         Diff      RiskOff 1 daily
  , Indicator "ust10y"   (Fred (SeriesId "DGS10"))          Diff      RiskOn  1 daily
  , Indicator "curve"    (Fred (SeriesId "T10Y2Y"))         Diff      RiskOn  1 daily
  , Indicator "hy_oas"   (Fred (SeriesId "BAMLH0A0HYM2"))   Diff      RiskOff 1 daily
  , Indicator "breakeven"(Fred (SeriesId "T10YIE"))         Diff      RiskOn  1 daily
  , Indicator "dollar"   (Fred (SeriesId "DTWEXBGS"))       LogReturn RiskOff 1 daily
  , Indicator "oil"      (Fred (SeriesId "DCOILWTICO"))     LogReturn RiskOn  1 daily
  , Indicator "claims"   (Fred (SeriesId "ICSA"))           Diff      RiskOff 5 (Window 52)
  , Indicator "gold"     (Price (Symbol "GLD"))             LogReturn RiskOff 0 daily
  ]

priceSymbolsNeeded :: [Indicator] -> [Symbol]
priceSymbolsNeeded inds = [ s | Indicator { indSource = Price s } <- inds ]

fredSeriesNeeded :: [Indicator] -> [SeriesId]
fredSeriesNeeded inds = [ s | Indicator { indSource = Fred s } <- inds ]
