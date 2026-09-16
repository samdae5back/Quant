{-# LANGUAGE GeneralizedNewtypeDeriving #-}
-- | Domain vocabulary shared by every module of the library.
--
-- Newtypes keep a FRED series id from being passed where a ticker is
-- expected and make units explicit in signatures.
module Quant.Types
  ( Symbol (..)
  , SeriesId (..)
  , Frequency (..)
  , Sign (..)
  , signMultiplier
  , Window (..)
  , Bps (..)
  , bpsToRate
  , TimeSeries (..)
  , tsLength
  , mkTimeSeries
  , Panel (..)
  , panelLength
  , panelColumn
  , mkPanel
  , nan
  , isNaNd
  ) where

import qualified Data.Text as T
import Data.Time.Calendar (Day)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS

import Quant.Core.Matrix (Matrix (..), column)

-- | A tradeable instrument identifier, e.g. @"SPY"@.
newtype Symbol = Symbol { unSymbol :: T.Text }
  deriving (Eq, Ord, Show)

-- | A FRED series identifier, e.g. @"DGS10"@.
newtype SeriesId = SeriesId { unSeriesId :: T.Text }
  deriving (Eq, Ord, Show)

data Frequency = Daily | Weekly | Monthly | Quarterly
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Direction convention for the state vector: a positive standardized
-- value must mean "risk-on". Indicators that rise in stress (VIX, credit
-- spreads) carry 'RiskOff' and get their sign flipped.
data Sign = RiskOn | RiskOff
  deriving (Eq, Show)

signMultiplier :: Sign -> Double
signMultiplier RiskOn = 1
signMultiplier RiskOff = -1

-- | Length of a rolling window in observations.
newtype Window = Window { unWindow :: Int }
  deriving (Eq, Ord, Show)

-- | Basis points.
newtype Bps = Bps { unBps :: Double }
  deriving (Eq, Ord, Show, Num)

bpsToRate :: Bps -> Double
bpsToRate (Bps b) = b / 10000

-- | A single series of observations, sorted by date ascending, one value per
-- date. 'tsRelease' is the date the value became public; when the source
-- gives none it equals the observation date and 'Quant.Indicator' adds a
-- conservative lag.
data TimeSeries = TimeSeries
  { tsDates   :: !(V.Vector Day)
  , tsRelease :: !(V.Vector Day)
  , tsValues  :: !(VS.Vector Double)
  }
  deriving (Eq, Show)

tsLength :: TimeSeries -> Int
tsLength = V.length . tsDates

-- | Build a series whose release date equals its observation date. Input must
-- already be sorted; unsorted input is a programming error and is rejected.
mkTimeSeries :: [(Day, Double)] -> Either String TimeSeries
mkTimeSeries obs
  | not sorted = Left "mkTimeSeries: dates must be strictly ascending"
  | otherwise = Right (TimeSeries ds ds vs)
  where
    ds = V.fromList (map fst obs)
    vs = VS.fromList (map snd obs)
    sorted = and (zipWith (<) (map fst obs) (drop 1 (map fst obs)))

-- | Several aligned series on a common date index: the @[T][K]@ panel that
-- the C kernels consume. Column @j@ is named @pNames ! j@.
data Panel = Panel
  { pDates  :: !(V.Vector Day)
  , pNames  :: !(V.Vector T.Text)
  , pMatrix :: !Matrix
  }
  deriving (Eq, Show)

panelLength :: Panel -> Int
panelLength = V.length . pDates

panelColumn :: Panel -> T.Text -> Maybe (VS.Vector Double)
panelColumn p name = column (pMatrix p) <$> V.elemIndex name (pNames p)

mkPanel :: V.Vector Day -> [(T.Text, VS.Vector Double)] -> Either String Panel
mkPanel dates cols'
  | any ((/= t) . VS.length . snd) cols' = Left "mkPanel: every column must have one value per date"
  | otherwise = Right Panel
      { pDates = dates
      , pNames = V.fromList (map fst cols')
      , pMatrix = Matrix t k (VS.generate (t * k) (\i -> let (a, b) = i `quotRem` k in snd (cols' !! b) VS.! a))
      }
  where
    t = V.length dates
    k = length cols'

nan :: Double
nan = 0 / 0

isNaNd :: Double -> Bool
isNaNd = isNaN
