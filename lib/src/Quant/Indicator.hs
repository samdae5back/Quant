-- | What an indicator is: a source, a transform that makes it stationary, a
-- sign convention, a publication lag and the standardisation window.
--
-- Indicator definitions are code, not configuration: a wrong transform or
-- sign is a bug the type checker and the test-suite should be able to see.
module Quant.Indicator
  ( Source (..)
  , Transform (..)
  , Indicator (..)
  , applyTransform
  , standardize
  ) where

import qualified Data.Text as T
import qualified Data.Vector.Storable as VS

import qualified Quant.Core.Series as S
import Quant.Types

data Source
  = Fred SeriesId     -- ^ a FRED series
  | Price Symbol      -- ^ a traded instrument's close, e.g. an ETF standing in for gold
  deriving (Eq, Show)

-- | How the raw level is turned into a stationary series before z-scoring.
data Transform
  = Level        -- ^ use as is (already a rate or spread)
  | Diff         -- ^ first difference (yields, spreads)
  | Return       -- ^ simple return (prices)
  | LogReturn    -- ^ log return (prices)
  deriving (Eq, Show)

data Indicator = Indicator
  { indName      :: T.Text     -- ^ column name in the state panel
  , indSource    :: Source
  , indTransform :: Transform
  , indSign      :: Sign       -- ^ 'RiskOff' flips the sign so that + always means risk-on
  , indLagDays   :: Integer    -- ^ publication lag added to observation dates
  , indZWindow   :: Window     -- ^ rolling window for the z-score
  }
  deriving (Eq, Show)

applyTransform :: Transform -> VS.Vector Double -> VS.Vector Double
applyTransform Level = id
applyTransform Diff = S.diff
applyTransform Return = S.returns
applyTransform LogReturn = S.logReturns

-- | Transform, rolling z-score and sign-adjust one aligned series.
standardize :: Indicator -> VS.Vector Double -> VS.Vector Double
standardize ind xs =
  VS.map (* signMultiplier (indSign ind))
    (S.rollingZScore (unWindow (indZWindow ind)) (applyTransform (indTransform ind) xs))
