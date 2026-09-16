{-# LANGUAGE OverloadedStrings #-}
-- | Two-asset regime tilt: hold a risky basket when the meta index reads
-- risk-on, shift toward the safe asset when it reads risk-off.
--
-- Parameters are data ('RegimeTiltParams', loadable from JSON); the logic is
-- code. Variants with different thresholds are different config files, not
-- different modules.
module Quant.Strategies.RegimeTilt
  ( RegimeTiltParams (..)
  , regimeTilt
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.Vector.Storable as VS

import Quant.Core.Matrix (generate)
import Quant.Regime (Regime (..), RegimeThresholds (..), classify)
import Quant.Strategy
import Quant.Types

data RegimeTiltParams = RegimeTiltParams
  { rtRisky         :: Symbol   -- ^ e.g. a quality-stock ETF or basket proxy
  , rtSafe          :: Symbol   -- ^ e.g. a T-bill ETF
  , rtThresholds    :: RegimeThresholds
  , rtRiskOnWeight  :: Double   -- ^ risky weight in the risk-on regime
  , rtNeutralWeight :: Double
  , rtRiskOffWeight :: Double
  , rtRebalance     :: Rebalance
  , rtCostBps       :: Double
  }
  deriving (Eq, Show)

instance FromJSON RegimeTiltParams where
  parseJSON = withObject "RegimeTiltParams" $ \o -> do
    risky <- Symbol <$> o .: "risky"
    safe <- Symbol <$> o .: "safe"
    on <- o .:? "riskOnAbove" .!= 0.25
    off <- o .:? "riskOffBelow" .!= (-0.25)
    wOn <- o .:? "riskOnWeight" .!= 1.0
    wNeutral <- o .:? "neutralWeight" .!= 0.6
    wOff <- o .:? "riskOffWeight" .!= 0.2
    reb <- o .:? "rebalance" .!= ("monthly" :: String)
    cost <- o .:? "costBps" .!= 5
    rebalance <- case reb of
      "daily" -> pure EveryBar
      "weekly" -> pure Weekly'
      "monthly" -> pure Monthly'
      other -> fail ("unknown rebalance: " ++ other)
    pure (RegimeTiltParams risky safe (RegimeThresholds on off) wOn wNeutral wOff rebalance cost)

instance ToJSON RegimeTiltParams where
  toJSON p = object
    [ "risky" .= unSymbol (rtRisky p)
    , "safe" .= unSymbol (rtSafe p)
    , "riskOnAbove" .= riskOnAbove (rtThresholds p)
    , "riskOffBelow" .= riskOffBelow (rtThresholds p)
    , "riskOnWeight" .= rtRiskOnWeight p
    , "neutralWeight" .= rtNeutralWeight p
    , "riskOffWeight" .= rtRiskOffWeight p
    , "rebalance" .= (case rtRebalance p of EveryBar -> "daily"; Weekly' -> "weekly"; Monthly' -> "monthly" :: String)
    , "costBps" .= rtCostBps p
    ]

regimeTilt :: RegimeTiltParams -> Strategy
regimeTilt p = Strategy
  { stratName = "regime-tilt"
  , stratUniverse = [rtRisky p, rtSafe p]
  , stratWeights = \input ->
      let t = panelLength (siPrices input)
          meta = maybe (VS.replicate t nan) id (siMeta input)
          riskyW i = case classify (rtThresholds p) (meta VS.! i) of
            RiskOnRegime -> rtRiskOnWeight p
            NeutralRegime -> rtNeutralWeight p
            RiskOffRegime -> rtRiskOffWeight p
      in generate t 2 (\i j -> let w = riskyW i in if j == 0 then w else 1 - w)
  , stratRebalance = rtRebalance p
  , stratFill = NextClose
  , stratCosts = CostModel (Bps (rtCostBps p))
  }
