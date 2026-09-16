-- | Regime statistics on the state panel and a coarse regime label.
--
-- Both statistics here are computed with the full-sample mean and covariance,
-- which is fine for describing history and NOT fine inside a backtest, where
-- the estimate at time t may only use data up to t. The rolling versions are
-- the next step on the roadmap.
module Quant.Regime
  ( Regime (..)
  , turbulence
  , absorption
  , classify
  , RegimeThresholds (..)
  ) where

import qualified Data.Vector.Storable as VS

import Quant.Core.Error (CoreError)
import Quant.Core.Linalg (Eigen (..), symEigen, symInverse)
import Quant.Core.Matrix (Matrix (..), cols, row)
import qualified Quant.Core.Regime as R
import Quant.Core.Stats (columnMeans, covariance)
import Quant.State (completeRows)
import Quant.Types

data Regime = RiskOnRegime | NeutralRegime | RiskOffRegime
  deriving (Eq, Ord, Show, Enum, Bounded)

completeMatrix :: Panel -> Matrix
completeMatrix p = Matrix (length keep) (cols m) (VS.concat (map (row m) keep))
  where
    m = pMatrix p
    keep = completeRows p

-- | Mahalanobis distance of every row from the full-sample centre.
turbulence :: Panel -> Either CoreError (VS.Vector Double)
turbulence p = do
  let complete = completeMatrix p
  cov <- covariance complete
  inv <- symInverse cov
  R.mahalanobisPanel (pMatrix p) (columnMeans complete) inv

-- | Share of variance captured by the top @m@ principal components.
absorption :: Int -> Panel -> Either CoreError Double
absorption m p = do
  cov <- covariance (completeMatrix p)
  eig <- symEigen cov
  R.absorptionRatio m (eigenValues eig)

data RegimeThresholds = RegimeThresholds
  { riskOnAbove   :: Double
  , riskOffBelow  :: Double
  }
  deriving (Eq, Show)

-- | Label a meta-index value. NaN is treated as neutral.
classify :: RegimeThresholds -> Double -> Regime
classify th x
  | isNaN x = NeutralRegime
  | x >= riskOnAbove th = RiskOnRegime
  | x <= riskOffBelow th = RiskOffRegime
  | otherwise = NeutralRegime
