-- | Technical indicators computed on a single traded price series.
--
-- These are the "test indicators" for rule-based strategies, as opposed to
-- the macro indicators in "Quant.Indicators" that feed the state vector.
-- All three are thin compositions of the C kernels in "Quant.Core.Series".
module Quant.Technical
  ( sma
  , momentum
  , realizedVol
  , tradingDaysPerYear
  ) where

import qualified Data.Vector.Storable as VS

import qualified Quant.Core.Series as S
import Quant.Types (nan)

tradingDaysPerYear :: Double
tradingDaysPerYear = 252

-- | Simple moving average of the level over the trailing @w@ bars.
sma :: Int -> VS.Vector Double -> VS.Vector Double
sma = S.rollingMean

-- | Total return over the trailing @n@ bars: @x_t / x_{t-n} - 1@. The first
-- @n@ entries are NaN, as is any entry whose base price is NaN or zero.
momentum :: Int -> VS.Vector Double -> VS.Vector Double
momentum n xs = VS.generate (VS.length xs) $ \i ->
  if i < n then nan else
    let base = xs VS.! (i - n)
        now = xs VS.! i
    in if isNaN base || isNaN now || base == 0 then nan else now / base - 1

-- | Annualised standard deviation of daily simple returns over the trailing
-- @w@ bars. Needs @w >= 2@ and @w + 1@ prices before the first finite value.
realizedVol :: Int -> VS.Vector Double -> VS.Vector Double
realizedVol w xs = VS.map (* sqrt tradingDaysPerYear) (S.rollingStd w (S.returns xs))
