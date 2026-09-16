-- | The strategy record: the six things that define a systematic strategy,
-- expressed as data and one pure function.
module Quant.Strategy
  ( Rebalance (..)
  , FillTiming (..)
  , CostModel (..)
  , StrategyInput (..)
  , Strategy (..)
  , rebalanceIndices
  ) where

import qualified Data.Text as T
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS

import Quant.Core.Matrix (Matrix)
import Quant.Data.Calendar (monthEnds, weekEnds)
import Quant.Types

data Rebalance = EveryBar | Weekly' | Monthly'
  deriving (Eq, Show)

-- | When a decision made at the close of bar t is filled. Only the simulator
-- contract's default exists today; @NextOpen@ needs open prices in the panel.
data FillTiming = NextClose
  deriving (Eq, Show)

newtype CostModel = CostModel { costBps :: Bps }
  deriving (Eq, Show)

-- | Everything a strategy may look at. Prices are the tradeable universe;
-- the state panel and meta index are optional signals aligned to the same dates.
data StrategyInput = StrategyInput
  { siPrices :: Panel
  , siState  :: Maybe Panel
  , siMeta   :: Maybe (VS.Vector Double)
  }

data Strategy = Strategy
  { stratName      :: T.Text
  , stratUniverse  :: [Symbol]                  -- ^ columns expected in 'siPrices', in order
  , stratWeights   :: StrategyInput -> Matrix   -- ^ target weights @[T][N]@ at every bar
  , stratRebalance :: Rebalance                 -- ^ how often the targets are actually applied
  , stratFill      :: FillTiming
  , stratCosts     :: CostModel
  }

-- | Bar indices on which a strategy trades under its schedule.
rebalanceIndices :: Rebalance -> Panel -> [Int]
rebalanceIndices EveryBar p = [0 .. panelLength p - 1]
rebalanceIndices Weekly' p = weekEnds (pDates p)
rebalanceIndices Monthly' p = monthEnds (pDates p)

_unused :: V.Vector ()
_unused = V.empty
