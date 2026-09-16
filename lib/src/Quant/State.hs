-- | Build the macro state vector panel: one standardized, sign-adjusted
-- column per indicator on a common date index.
module Quant.State
  ( buildState
  , completeRows
  ) where

import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Data.Time.Calendar (Day)

import Quant.Core.Matrix (rows, row)
import Quant.Data.Align (asOfWithLag)
import Quant.Indicator
import Quant.Types

-- | Align every indicator's raw series onto @dates@ by release date, then
-- transform and standardize it. The caller supplies the raw series looked up
-- from the cache, paired with its indicator.
buildState :: V.Vector Day -> [(Indicator, TimeSeries)] -> Either String Panel
buildState dates pairs = mkPanel dates
  [ (indName ind, standardize ind (asOfWithLag (indLagDays ind) dates ts)) | (ind, ts) <- pairs ]

-- | Row indices where every column is finite. Covariance and PCA are only
-- meaningful on these rows.
completeRows :: Panel -> [Int]
completeRows p = [ i | i <- [0 .. rows m - 1], VS.all (not . isNaN) (row m i) ]
  where m = pMatrix p
