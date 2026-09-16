-- | Where a stock sits in macro space: its beta vector against the state
-- panel's changes, and how similar that vector is to a target direction.
module Quant.Exposure
  ( betaVector
  , cosineSimilarity
  ) where

import qualified Data.Vector.Storable as VS

import Quant.Core.Error (CoreError)
import Quant.Core.Stats (Ols (..), ols)
import Quant.Types

-- | Regress an asset's returns on the state panel (one regressor per
-- indicator, intercept included). Rows with NaN are dropped by the kernel.
betaVector :: Panel -> VS.Vector Double -> Either CoreError (VS.Vector Double)
betaVector state assetReturns = olsBeta <$> ols True (pMatrix state) assetReturns

-- | Cosine similarity in @[-1, 1]@; zero vectors give NaN.
cosineSimilarity :: VS.Vector Double -> VS.Vector Double -> Double
cosineSimilarity a b
  | na == 0 || nb == 0 = nan
  | otherwise = VS.sum (VS.zipWith (*) a b) / (na * nb)
  where
    na = sqrt (VS.sum (VS.map (^ (2 :: Int)) a))
    nb = sqrt (VS.sum (VS.map (^ (2 :: Int)) b))
