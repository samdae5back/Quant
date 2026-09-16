-- | Safe wrappers over the @stats.h@ kernels.
module Quant.Core.Stats
  ( mean
  , columnMeans
  , covariance
  , correlation
  , Ols (..)
  , ols
  ) where

import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Storable.Mutable as VSM
import Foreign.C.Types (CInt, CSize)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peek)
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.Error (CoreError (..), Status (..), checkStatus, checkStatusEither)
import Quant.Core.FFI
import Quant.Core.Matrix

-- | NaN-skipping arithmetic mean. Empty input throws.
mean :: VS.Vector Double -> Double
mean xs = unsafePerformIO $ alloca $ \po -> do
  rc <- VS.unsafeWith xs $ \px -> c_qc_mean px (fromIntegral (VS.length xs)) po
  checkStatus "qc_mean" rc
  peek po
{-# NOINLINE mean #-}

-- | Per-column NaN-skipping means of a @[T][K]@ panel.
columnMeans :: Matrix -> VS.Vector Double
columnMeans m = unsafePerformIO $ do
  out <- VSM.new (cols m)
  rc <- unsafeWithMatrix m $ \pp -> VSM.unsafeWith out $ \po ->
          c_qc_column_means pp (fromIntegral (rows m)) (fromIntegral (cols m)) po
  checkStatus "qc_column_means" rc
  VS.unsafeFreeze out
{-# NOINLINE columnMeans #-}

-- | Shared driver for kernels of shape @(panel, T, K, out[K*K])@.
squareKernel :: String
             -> (Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt)
             -> Matrix -> Either CoreError Matrix
squareKernel name kernel m = unsafePerformIO $ do
  let k = cols m
  out <- VSM.new (k * k)
  rc <- unsafeWithMatrix m $ \pp -> VSM.unsafeWith out $ \po ->
          kernel pp (fromIntegral (rows m)) (fromIntegral k) po
  e <- checkStatusEither name rc
  case e of
    Left err -> pure (Left err)
    Right () -> Right . Matrix k k <$> VS.unsafeFreeze out
{-# NOINLINE squareKernel #-}

-- | Sample covariance of the columns of a @[T][K]@ panel; rows with NaN are dropped.
covariance :: Matrix -> Either CoreError Matrix
covariance = squareKernel "qc_covariance" c_qc_covariance

-- | Pearson correlation of the columns of a @[T][K]@ panel.
correlation :: Matrix -> Either CoreError Matrix
correlation = squareKernel "qc_correlation" c_qc_correlation

data Ols = Ols
  { olsBeta      :: VS.Vector Double  -- ^ one coefficient per regressor column
  , olsIntercept :: Maybe Double
  , olsResidVar  :: Double
  }
  deriving (Eq, Show)

-- | Ordinary least squares of @y@ on the columns of @x@.
ols :: Bool -> Matrix -> VS.Vector Double -> Either CoreError Ols
ols withIntercept x y
  | VS.length y /= rows x =
      Left (CoreError InvalidArgument "qc_ols" "y length must equal the number of rows of X")
  | otherwise = unsafePerformIO $ do
      let k = cols x
          p = k + (if withIntercept then 1 else 0)
      beta <- VSM.new p
      alloca $ \prv -> do
        rc <- unsafeWithMatrix x $ \px -> VS.unsafeWith y $ \py -> VSM.unsafeWith beta $ \pb ->
                c_qc_ols px py (fromIntegral (rows x)) (fromIntegral k)
                         (if withIntercept then 1 else 0) pb prv
        e <- checkStatusEither "qc_ols" rc
        case e of
          Left err -> pure (Left err)
          Right () -> do
            b <- VS.unsafeFreeze beta
            rv <- peek prv
            pure . Right $ Ols
              { olsBeta = VS.take k b
              , olsIntercept = if withIntercept then Just (b VS.! k) else Nothing
              , olsResidVar = rv
              }
{-# NOINLINE ols #-}
