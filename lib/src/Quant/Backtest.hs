-- | Run a strategy over a price panel: compute target weights, apply the
-- rebalance schedule, hand the result to the C simulator.
module Quant.Backtest
  ( BacktestResult (..)
  , runBacktest
  , applySchedule
  ) where

import qualified Data.Text as T
import Data.Time.Calendar (Day)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS

import Quant.Core.Error (CoreError (..), Status (..))
import Quant.Core.Matrix (Matrix (..), cols, generate, rows, (!))
import Quant.Core.Simulate (SimResult (..), simulate)
import Quant.Strategy
import Quant.Types

data BacktestResult = BacktestResult
  { brStrategy :: T.Text
  , brDates    :: V.Vector Day
  , brEquity   :: VS.Vector Double
  , brTurnover :: VS.Vector Double
  , brWeights  :: Matrix
  }

-- | Hold the weights chosen on rebalance bars until the next rebalance bar.
-- Bars before the first rebalance are all-cash (zero weights).
applySchedule :: [Int] -> Matrix -> Matrix
applySchedule idxs w = generate (rows w) (cols w) (\i j -> maybe 0 (\src -> w ! (src, j)) (lastRebalance i))
  where
    lastRebalance i = case takeWhile (<= i) idxs of
      [] -> Nothing
      xs -> Just (last xs)

runBacktest :: Strategy -> StrategyInput -> Either CoreError BacktestResult
runBacktest strat input
  | cols (pMatrix prices) /= length (stratUniverse strat) =
      Left (CoreError InvalidArgument "runBacktest" "price panel columns must match the strategy universe")
  | otherwise = do
      let raw = stratWeights strat input
          scheduled = applySchedule (rebalanceIndices (stratRebalance strat) prices) raw
      sim <- simulate (unBps (costBps (stratCosts strat))) (pMatrix prices) scheduled
      pure BacktestResult
        { brStrategy = stratName strat
        , brDates = pDates prices
        , brEquity = simEquity sim
        , brTurnover = simTurnover sim
        , brWeights = scheduled
        }
  where
    prices = siPrices input
