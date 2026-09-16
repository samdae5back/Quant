-- | Safe wrapper over @simulate.h@: turn a target-weight panel into an equity curve.
module Quant.Core.Simulate
  ( SimResult (..)
  , simulate
  ) where

import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Storable.Mutable as VSM
import Foreign.C.Types (CDouble (..))
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.Error (CoreError (..), Status (..), checkStatusEither)
import Quant.Core.FFI
import Quant.Core.Matrix

data SimResult = SimResult
  { simEquity   :: VS.Vector Double  -- ^ starts at 1.0 (net of the entry cost)
  , simTurnover :: VS.Vector Double  -- ^ sum of absolute weight changes per bar
  }
  deriving (Eq, Show)

-- | @simulate costBps prices weights@. Both panels are @[T][N]@ and must agree
-- in shape. Weights at row @t@ earn the return from @t@ to @t+1@.
simulate :: Double -> Matrix -> Matrix -> Either CoreError SimResult
simulate costBps prices weights
  | rows prices /= rows weights || cols prices /= cols weights =
      Left (CoreError InvalidArgument "qc_simulate" "prices and weights must have the same shape")
  | otherwise = unsafePerformIO $ do
      let t = rows prices
          n = cols prices
      eq <- VSM.new t
      to <- VSM.new t
      rc <- unsafeWithMatrix prices $ \pp -> unsafeWithMatrix weights $ \pw ->
              VSM.unsafeWith eq $ \pe -> VSM.unsafeWith to $ \pt ->
                c_qc_simulate pp pw (fromIntegral t) (fromIntegral n) (CDouble costBps) pe pt
      e <- checkStatusEither "qc_simulate" rc
      case e of
        Left err -> pure (Left err)
        Right () -> Right <$> (SimResult <$> VS.unsafeFreeze eq <*> VS.unsafeFreeze to)
{-# NOINLINE simulate #-}
