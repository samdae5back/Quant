{-# LANGUAGE OverloadedStrings #-}
-- | The most basic rule-based strategy in the repository: a trend filter
-- with volatility targeting, built from the three indicators in
-- "Quant.Technical".
--
--   * Trend:    hold the risky asset only while its price is above its SMA.
--   * Momentum: and only while its trailing return is positive.
--   * Vol:      size the position as @targetVol / realizedVol@, capped at
--               @maxWeight@, so calm markets get full exposure and turbulent
--               ones get less.
--
-- Whatever is not in the risky asset sits in the safe asset. Before the
-- indicators have warmed up the strategy holds the safe asset only.
module Quant.Strategies.TrendFilter
  ( TrendFilterParams (..)
  , trendFilter
  , trendFilterWeight
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.Vector.Storable as VS

import Quant.Core.Matrix (generate, (!))
import Quant.Strategy
import Quant.Technical (momentum, realizedVol, sma)
import Quant.Types

data TrendFilterParams = TrendFilterParams
  { tfRisky          :: Symbol
  , tfSafe           :: Symbol
  , tfSmaWindow      :: Int       -- ^ bars, e.g. 200
  , tfMomentumWindow :: Int       -- ^ bars, e.g. 252
  , tfVolWindow      :: Int       -- ^ bars, e.g. 20
  , tfTargetVol      :: Double    -- ^ annualised, e.g. 0.15
  , tfMaxWeight      :: Double    -- ^ cap on the risky weight, e.g. 1.0
  , tfRebalance      :: Rebalance
  , tfCostBps        :: Double
  }
  deriving (Eq, Show)

instance FromJSON TrendFilterParams where
  parseJSON = withObject "TrendFilterParams" $ \o -> do
    risky <- Symbol <$> o .: "risky"
    safe <- Symbol <$> o .: "safe"
    smaW <- o .:? "smaWindow" .!= 200
    momW <- o .:? "momentumWindow" .!= 252
    volW <- o .:? "volWindow" .!= 20
    target <- o .:? "targetVol" .!= 0.15
    cap <- o .:? "maxWeight" .!= 1.0
    reb <- o .:? "rebalance" .!= ("monthly" :: String)
    cost <- o .:? "costBps" .!= 5
    rebalance <- case reb of
      "daily" -> pure EveryBar
      "weekly" -> pure Weekly'
      "monthly" -> pure Monthly'
      other -> fail ("unknown rebalance: " ++ other)
    pure (TrendFilterParams risky safe smaW momW volW target cap rebalance cost)

instance ToJSON TrendFilterParams where
  toJSON p = object
    [ "risky" .= unSymbol (tfRisky p)
    , "safe" .= unSymbol (tfSafe p)
    , "smaWindow" .= tfSmaWindow p
    , "momentumWindow" .= tfMomentumWindow p
    , "volWindow" .= tfVolWindow p
    , "targetVol" .= tfTargetVol p
    , "maxWeight" .= tfMaxWeight p
    , "rebalance" .= (case tfRebalance p of EveryBar -> "daily"; Weekly' -> "weekly"; Monthly' -> "monthly" :: String)
    , "costBps" .= tfCostBps p
    ]

-- | The decision rule for one bar, exposed for testing.
--
-- @trendFilterWeight params price smaValue momentumValue volValue@ returns
-- the risky weight in @[0, maxWeight]@. Any NaN input means "not yet
-- warmed up" and yields zero.
trendFilterWeight :: TrendFilterParams -> Double -> Double -> Double -> Double -> Double
trendFilterWeight p price s m v
  | any isNaN [price, s, m, v] = 0
  | price > s && m > 0 = if v <= 0 then tfMaxWeight p else min (tfMaxWeight p) (tfTargetVol p / v)
  | otherwise = 0

trendFilter :: TrendFilterParams -> Strategy
trendFilter p = Strategy
  { stratName = "trend-filter"
  , stratUniverse = [tfRisky p, tfSafe p]
  , stratWeights = \input ->
      let prices = pMatrix (siPrices input)
          t = panelLength (siPrices input)
          risky = VS.generate t (\i -> prices ! (i, 0))
          smaV = sma (tfSmaWindow p) risky
          momV = momentum (tfMomentumWindow p) risky
          volV = realizedVol (tfVolWindow p) risky
          w i = trendFilterWeight p (risky VS.! i) (smaV VS.! i) (momV VS.! i) (volV VS.! i)
      in generate t 2 (\i j -> let x = w i in if j == 0 then x else 1 - x)
  , stratRebalance = tfRebalance p
  , stratFill = NextClose
  , stratCosts = CostModel (Bps (tfCostBps p))
  }
