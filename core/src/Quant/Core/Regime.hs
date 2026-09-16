-- | Safe wrappers over the @regime.h@ kernels: geometry of the state vector.
module Quant.Core.Regime
  ( mahalanobis
  , mahalanobisPanel
  , absorptionRatio
  ) where

import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Storable.Mutable as VSM
import Foreign.Marshal.Alloc (alloca)
import Foreign.Storable (peek)
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.Error (CoreError (..), Status (..), checkStatusEither)
import Quant.Core.FFI
import Quant.Core.Matrix

-- | Distance of one observation from the centre @mu@ under the metric @covInv@.
mahalanobis :: VS.Vector Double -> VS.Vector Double -> Matrix -> Either CoreError Double
mahalanobis x mu covInv
  | VS.length x /= k || VS.length mu /= k || rows covInv /= k =
      Left (CoreError InvalidArgument "qc_mahalanobis" "dimension mismatch")
  | otherwise = unsafePerformIO $ alloca $ \po -> do
      rc <- VS.unsafeWith x $ \px -> VS.unsafeWith mu $ \pm -> unsafeWithMatrix covInv $ \pc ->
              c_qc_mahalanobis px pm pc (fromIntegral k) po
      e <- checkStatusEither "qc_mahalanobis" rc
      either (pure . Left) (\_ -> Right <$> peek po) e
  where k = cols covInv
{-# NOINLINE mahalanobis #-}

-- | Distance of every row of a @[T][K]@ panel.
mahalanobisPanel :: Matrix -> VS.Vector Double -> Matrix -> Either CoreError (VS.Vector Double)
mahalanobisPanel panel mu covInv
  | VS.length mu /= k || rows covInv /= k || cols covInv /= k =
      Left (CoreError InvalidArgument "qc_mahalanobis_panel" "dimension mismatch")
  | otherwise = unsafePerformIO $ do
      out <- VSM.new (rows panel)
      rc <- unsafeWithMatrix panel $ \pp -> VS.unsafeWith mu $ \pm ->
              unsafeWithMatrix covInv $ \pc -> VSM.unsafeWith out $ \po ->
                c_qc_mahalanobis_panel pp (fromIntegral (rows panel)) (fromIntegral k) pm pc po
      e <- checkStatusEither "qc_mahalanobis_panel" rc
      either (pure . Left) (\_ -> Right <$> VS.unsafeFreeze out) e
  where k = cols panel
{-# NOINLINE mahalanobisPanel #-}

-- | Share of variance explained by the top @m@ of descending eigenvalues.
absorptionRatio :: Int -> VS.Vector Double -> Either CoreError Double
absorptionRatio m evals = unsafePerformIO $ alloca $ \po -> do
  rc <- VS.unsafeWith evals $ \pe ->
          c_qc_absorption_ratio pe (fromIntegral (VS.length evals)) (fromIntegral m) po
  e <- checkStatusEither "qc_absorption_ratio" rc
  either (pure . Left) (\_ -> Right <$> peek po) e
{-# NOINLINE absorptionRatio #-}
