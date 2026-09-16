{-# LANGUAGE ForeignFunctionInterface #-}
-- | Raw foreign imports. This is the only module that knows the C signatures.
--
-- Every import is @unsafe@: the kernels are short, allocation-free, never call
-- back into Haskell and never block, so the cheaper calling convention is
-- appropriate. If a kernel ever grows to run for seconds (a long Monte Carlo,
-- say), switch that single import to @safe@ so the RTS can keep running GC
-- and other Haskell threads meanwhile.
module Quant.Core.FFI
  ( c_qc_status_str
  , c_qc_version
  , c_qc_diff
  , c_qc_returns
  , c_qc_log_returns
  , c_qc_rolling_mean
  , c_qc_rolling_std
  , c_qc_rolling_zscore
  , c_qc_ewma
  , c_qc_mean
  , c_qc_column_means
  , c_qc_covariance
  , c_qc_correlation
  , c_qc_ols
  , c_qc_cholesky
  , c_qc_cholesky_solve
  , c_qc_sym_inverse
  , c_qc_sym_eigen
  , c_qc_mahalanobis
  , c_qc_mahalanobis_panel
  , c_qc_absorption_ratio
  , c_qc_simulate
  ) where

import Foreign.C.String (CString)
import Foreign.C.Types (CDouble (..), CInt (..), CSize (..))
import Foreign.Ptr (Ptr)

foreign import ccall unsafe "qcore/qcore.h qc_status_str"
  c_qc_status_str :: CInt -> IO CString

foreign import ccall unsafe "qcore/qcore.h qc_version"
  c_qc_version :: IO CString

-- series.h --------------------------------------------------------------

foreign import ccall unsafe "qcore/series.h qc_diff"
  c_qc_diff :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_returns"
  c_qc_returns :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_log_returns"
  c_qc_log_returns :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_rolling_mean"
  c_qc_rolling_mean :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_rolling_std"
  c_qc_rolling_std :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_rolling_zscore"
  c_qc_rolling_zscore :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/series.h qc_ewma"
  c_qc_ewma :: Ptr Double -> CSize -> CDouble -> Ptr Double -> IO CInt

-- stats.h ---------------------------------------------------------------

foreign import ccall unsafe "qcore/stats.h qc_mean"
  c_qc_mean :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/stats.h qc_column_means"
  c_qc_column_means :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/stats.h qc_covariance"
  c_qc_covariance :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/stats.h qc_correlation"
  c_qc_correlation :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/stats.h qc_ols"
  c_qc_ols :: Ptr Double -> Ptr Double -> CSize -> CSize -> CInt
           -> Ptr Double -> Ptr Double -> IO CInt

-- linalg.h --------------------------------------------------------------

foreign import ccall unsafe "qcore/linalg.h qc_cholesky"
  c_qc_cholesky :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/linalg.h qc_cholesky_solve"
  c_qc_cholesky_solve :: Ptr Double -> CSize -> Ptr Double -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/linalg.h qc_sym_inverse"
  c_qc_sym_inverse :: Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/linalg.h qc_sym_eigen"
  c_qc_sym_eigen :: Ptr Double -> CSize -> Ptr Double -> Ptr Double -> CSize -> IO CInt

-- regime.h --------------------------------------------------------------

foreign import ccall unsafe "qcore/regime.h qc_mahalanobis"
  c_qc_mahalanobis :: Ptr Double -> Ptr Double -> Ptr Double -> CSize -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/regime.h qc_mahalanobis_panel"
  c_qc_mahalanobis_panel :: Ptr Double -> CSize -> CSize -> Ptr Double -> Ptr Double
                         -> Ptr Double -> IO CInt

foreign import ccall unsafe "qcore/regime.h qc_absorption_ratio"
  c_qc_absorption_ratio :: Ptr Double -> CSize -> CSize -> Ptr Double -> IO CInt

-- simulate.h ------------------------------------------------------------

foreign import ccall unsafe "qcore/simulate.h qc_simulate"
  c_qc_simulate :: Ptr Double -> Ptr Double -> CSize -> CSize -> CDouble
                -> Ptr Double -> Ptr Double -> IO CInt
