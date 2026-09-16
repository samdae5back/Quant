-- | Safe wrappers over the @linalg.h@ kernels. Matrices must be square and
-- at most 'maxDim' on a side; larger inputs return 'InvalidArgument'.
module Quant.Core.Linalg
  ( maxDim
  , cholesky
  , choleskySolve
  , symInverse
  , Eigen (..)
  , symEigen
  ) where

import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Storable.Mutable as VSM
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.Error (CoreError (..), Status (..), checkStatusEither)
import Quant.Core.FFI
import Quant.Core.Matrix

-- | Mirrors @QC_MAX_DIM@ in @qcore.h@.
maxDim :: Int
maxDim = 64

squareCheck :: String -> Matrix -> Either CoreError Int
squareCheck kernel m
  | rows m /= cols m = Left (CoreError InvalidArgument kernel "matrix must be square")
  | rows m == 0 = Left (CoreError InvalidArgument kernel "matrix must be non-empty")
  | rows m > maxDim = Left (CoreError InvalidArgument kernel "matrix exceeds QC_MAX_DIM")
  | otherwise = Right (rows m)

-- | Lower-triangular Cholesky factor @L@ with @A = L L^T@.
cholesky :: Matrix -> Either CoreError Matrix
cholesky a = squareCheck "qc_cholesky" a >>= \n -> unsafePerformIO $ do
  out <- VSM.new (n * n)
  rc <- unsafeWithMatrix a $ \pa -> VSM.unsafeWith out $ \po ->
          c_qc_cholesky pa (fromIntegral n) po
  e <- checkStatusEither "qc_cholesky" rc
  either (pure . Left) (\_ -> Right . Matrix n n <$> VS.unsafeFreeze out) e
{-# NOINLINE cholesky #-}

-- | Solve @(L L^T) x = b@ given the factor @L@ from 'cholesky'.
choleskySolve :: Matrix -> VS.Vector Double -> Either CoreError (VS.Vector Double)
choleskySolve l b = squareCheck "qc_cholesky_solve" l >>= \n ->
  if VS.length b /= n
    then Left (CoreError InvalidArgument "qc_cholesky_solve" "rhs length mismatch")
    else unsafePerformIO $ do
      out <- VSM.new n
      rc <- unsafeWithMatrix l $ \pl -> VS.unsafeWith b $ \pb -> VSM.unsafeWith out $ \po ->
              c_qc_cholesky_solve pl (fromIntegral n) pb po
      e <- checkStatusEither "qc_cholesky_solve" rc
      either (pure . Left) (\_ -> Right <$> VS.unsafeFreeze out) e
{-# NOINLINE choleskySolve #-}

-- | Inverse of a symmetric positive definite matrix.
symInverse :: Matrix -> Either CoreError Matrix
symInverse a = squareCheck "qc_sym_inverse" a >>= \n -> unsafePerformIO $ do
  out <- VSM.new (n * n)
  rc <- unsafeWithMatrix a $ \pa -> VSM.unsafeWith out $ \po ->
          c_qc_sym_inverse pa (fromIntegral n) po
  e <- checkStatusEither "qc_sym_inverse" rc
  either (pure . Left) (\_ -> Right . Matrix n n <$> VS.unsafeFreeze out) e
{-# NOINLINE symInverse #-}

data Eigen = Eigen
  { eigenValues  :: VS.Vector Double  -- ^ descending
  , eigenVectors :: Matrix            -- ^ column @j@ belongs to @eigenValues ! j@
  }
  deriving (Eq, Show)

-- | Eigen-decomposition of a symmetric matrix (cyclic Jacobi).
symEigen :: Matrix -> Either CoreError Eigen
symEigen a = squareCheck "qc_sym_eigen" a >>= \n -> unsafePerformIO $ do
  vals <- VSM.new n
  vecs <- VSM.new (n * n)
  rc <- unsafeWithMatrix a $ \pa -> VSM.unsafeWith vals $ \pv -> VSM.unsafeWith vecs $ \pe ->
          c_qc_sym_eigen pa (fromIntegral n) pv pe 0
  e <- checkStatusEither "qc_sym_eigen" rc
  case e of
    Left err -> pure (Left err)
    Right () -> do
      vs <- VS.unsafeFreeze vals
      es <- VS.unsafeFreeze vecs
      pure (Right (Eigen vs (Matrix n n es)))
{-# NOINLINE symEigen #-}
