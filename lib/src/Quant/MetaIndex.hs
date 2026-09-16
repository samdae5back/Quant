-- | The meta index: a weighted sum of the state vector's columns.
--
-- 'Equal' and 'PCA' have no free parameters and are the recommended
-- defaults. 'Fixed' weights must come from an economic prior, never from a
-- fit against the thing you intend to predict.
module Quant.MetaIndex
  ( Weighting (..)
  , weights
  , metaIndex
  ) where

import qualified Data.Vector.Storable as VS

import Quant.Core.Error (CoreError)
import Quant.Core.Linalg (Eigen (..), symEigen)
import Quant.Core.Matrix (Matrix (..), column, cols, rows, row)
import Quant.Core.Stats (covariance)
import Quant.State (completeRows)
import Quant.Types

data Weighting
  = Equal
  | Fixed (VS.Vector Double)
  | PCA                       -- ^ first principal component of the complete rows
  deriving (Eq, Show)

-- | Resolve a weighting scheme into one weight per column, normalised to sum
-- to one in absolute value.
weights :: Weighting -> Panel -> Either CoreError (VS.Vector Double)
weights Equal p = Right (VS.replicate k (1 / fromIntegral k)) where k = cols (pMatrix p)
weights (Fixed w) _ = Right (normalise w)
weights PCA p = do
  let m = pMatrix p
      keep = completeRows p
      complete = Matrix (length keep) (cols m) (VS.concat (map (row m) keep))
  cov <- covariance complete
  eig <- symEigen cov
  let pc1 = column (eigenVectors eig) 0
      -- orient so that the component points "risk-on": positive loading sum
      oriented = if VS.sum pc1 < 0 then VS.map negate pc1 else pc1
  pure (normalise oriented)

normalise :: VS.Vector Double -> VS.Vector Double
normalise w = let s = VS.sum (VS.map abs w) in if s == 0 then w else VS.map (/ s) w

-- | @M_t = w . s_t@; a row with any NaN gives NaN.
metaIndex :: VS.Vector Double -> Panel -> VS.Vector Double
metaIndex w p = VS.generate (rows m) $ \i ->
  let r = row m i in if VS.any isNaN r then nan else VS.sum (VS.zipWith (*) w r)
  where m = pMatrix p
