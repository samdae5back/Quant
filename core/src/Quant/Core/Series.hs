-- | Safe wrappers over the @series.h@ kernels.
--
-- All functions are pure: same input, same output, no side effects. Invalid
-- arguments (empty input, window larger than the series) throw 'CoreError'.
module Quant.Core.Series
  ( diff
  , returns
  , logReturns
  , rollingMean
  , rollingStd
  , rollingZScore
  , ewma
  ) where

import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Storable.Mutable as VSM
import Foreign.C.Types (CDouble (..), CInt, CSize)
import Foreign.Ptr (Ptr)
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.Error (checkStatus)
import Quant.Core.FFI

-- | Run a kernel of shape @(in, n, out)@ with a fresh output buffer of length n.
unary :: String -> (Ptr Double -> CSize -> Ptr Double -> IO CInt)
      -> VS.Vector Double -> VS.Vector Double
unary name kernel xs = unsafePerformIO $ do
  let n = VS.length xs
  out <- VSM.new n
  rc <- VS.unsafeWith xs $ \px -> VSM.unsafeWith out $ \po ->
          kernel px (fromIntegral n) po
  checkStatus name rc
  VS.unsafeFreeze out
{-# NOINLINE unary #-}

-- | Same, for kernels that take a window argument.
windowed :: String -> (Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt)
         -> Int -> VS.Vector Double -> VS.Vector Double
windowed name kernel w xs = unsafePerformIO $ do
  let n = VS.length xs
  out <- VSM.new n
  rc <- VS.unsafeWith xs $ \px -> VSM.unsafeWith out $ \po ->
          kernel px (fromIntegral n) (fromIntegral w) po
  checkStatus name rc
  VS.unsafeFreeze out
{-# NOINLINE windowed #-}

-- | First difference; the first element is NaN.
diff :: VS.Vector Double -> VS.Vector Double
diff = unary "qc_diff" c_qc_diff

-- | Simple returns @x_t / x_{t-1} - 1@; the first element is NaN.
returns :: VS.Vector Double -> VS.Vector Double
returns = unary "qc_returns" c_qc_returns

-- | Log returns; the first element is NaN.
logReturns :: VS.Vector Double -> VS.Vector Double
logReturns = unary "qc_log_returns" c_qc_log_returns

-- | Trailing mean over @w@ observations; the first @w-1@ are NaN.
rollingMean :: Int -> VS.Vector Double -> VS.Vector Double
rollingMean = windowed "qc_rolling_mean" c_qc_rolling_mean

-- | Trailing sample standard deviation over @w >= 2@ observations.
rollingStd :: Int -> VS.Vector Double -> VS.Vector Double
rollingStd = windowed "qc_rolling_std" c_qc_rolling_std

-- | Trailing z-score: @(x - mean) / std@ over the window ending at each point.
rollingZScore :: Int -> VS.Vector Double -> VS.Vector Double
rollingZScore = windowed "qc_rolling_zscore" c_qc_rolling_zscore

-- | Exponentially weighted moving average with smoothing factor @0 < alpha <= 1@.
ewma :: Double -> VS.Vector Double -> VS.Vector Double
ewma alpha xs = unsafePerformIO $ do
  let n = VS.length xs
  out <- VSM.new n
  rc <- VS.unsafeWith xs $ \px -> VSM.unsafeWith out $ \po ->
          c_qc_ewma px (fromIntegral n) (CDouble alpha) po
  checkStatus "qc_ewma" rc
  VS.unsafeFreeze out
{-# NOINLINE ewma #-}
